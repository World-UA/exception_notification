require 'action_mailer'
require 'pp'
require 'fileutils'
require 'exception_notifier/report'

class ExceptionNotifier
  class Notifier < ActionMailer::Base
    self.mailer_name = 'exception_notifier'
    self.append_view_path "#{File.dirname(__FILE__)}/views"

    class << self
      def default_sender_address
        %("Exception Notifier" <no-reply@eticket.ua>)
      end

      def default_exception_recipients
        ['volodymyr.shpak@pilot.ua']
      end

      def default_email_prefix
        "[ERROR] "
      end

      def default_sections
        %w(request session environment backtrace)
      end

      def default_options
        { :sender_address => default_sender_address,
          :exception_recipients => default_exception_recipients,
          :email_prefix => default_email_prefix,
          :sections => default_sections }
      end
    end

    class MissingController
      def method_missing(*args, &block)
      end
    end

    def exception_notification(env, exception)
      @env        = env
      @exception  = exception
      @options    = (env['exception_notifier.options'] || {}).reverse_merge(self.class.default_options)
      @kontroller = env['action_controller.instance'] || MissingController.new
      @request    = ActionDispatch::Request.new(env)
      @backtrace  = clean_backtrace(exception)
      @sections   = @options[:sections]
      data        = env['exception_notifier.exception_data'] || {}

      data.each do |name, value|
        instance_variable_set("@#{name}", value)
      end

      check_directory
      File.open(file_name, "w") { |f| f.write(render("#{mailer_name}/exception_notification"))}

      # Report and notification
      report = ExceptionNotifier::Report.new(exception, {:dir_name => dir_name})
      report.update
      if report.notify?
        email_notification.deliver
      end
    end

    def email_notification
      prefix   = "#{@options[:email_prefix]}#{@kontroller.controller_name}##{@kontroller.action_name}"
      subject  = "#{prefix} (#{@exception.class}) #{@exception.message.inspect}"

      mail(:to => @options[:exception_recipients], :from => @options[:sender_address], :subject => subject) do |format|
        format.text { render "#{mailer_name}/exception_notification" }
      end
    end

    private

      def check_directory
        FileUtils.mkdir_p(dir_name)
      end

      def file_name
        dir_name.join(Time.current.strftime('%H_%M_%S_') << @exception.class.name << ".exception")
      end

      def dir_name
        Rails.root.join("log", "exceptions", Date.current.strftime('%d_%m_%Y'))
      end
      
      def clean_backtrace(exception)
        Rails.respond_to?(:backtrace_cleaner) ?
          Rails.backtrace_cleaner.send(:filter, exception.backtrace) :
          exception.backtrace
      end
      
      helper_method :inspect_object
      
      def inspect_object(object)
        case object
        when Hash, Array
          object.inspect
        when ActionController::Base
          "#{object.controller_name}##{object.action_name}"
        else
          object.to_s
        end
      end
      
  end
end
