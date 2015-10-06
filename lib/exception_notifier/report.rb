class ExceptionNotifier
  class Report

    def initialize(exception, options = {})
      @options = options.reverse_merge(default_options)
      @host = @options[:host]
      @exception = exception
      create_stats_file
      @data = load_stats_data
    end

    def update
      p "******************"
      p @data

      @data[@host]['exceptions'][time_str] = @exception.class.name
      store_stats_data
    end

    def notify?
      exceptions = @data[@host]['exceptions']
      if exceptions.size > @options[:min_count]
        seconds_beetween_exceptions = exceptions.keys.last(@options[:min_count]).each_cons(2).map { |a,b| Time.parse(b) - Time.parse(a) }
        if seconds_beetween_exceptions.max <= @options[:min_time_difference] &&
            (@data[@host]['notifications'].empty? || Time.parse(time_str) - Time.parse(@data[@host]['notifications'].last) >= @options[:notifications_delay])

          @data[@host]['notifications'] << time_str
          store_stats_data
          true
        else
          false
        end
      else
        false
      end
    end

    private
    def default_options
      { :dir_name => Pathname.new('/var/log'),
        :host => 'default',
        :min_count => 5,
        :min_time_difference => 60,
        :notifications_delay => 600 }
    end

    def time_str
      @time_str ||= Time.current.strftime('%H:%M:%S')
    end

    def stats_file_name
      @stats_file_name ||= @options[:dir_name].join("exception.yml")
    end

    def create_stats_file
      yml_skeleton = {'default' => {'exceptions' => {}, 'notifications' => []}}
      File.open(stats_file_name, "w"){ |o| o.write(yml_skeleton.to_yaml) } unless File.exist?(stats_file_name)
    end

    def load_stats_data
      YAML.load_file(stats_file_name)
    end

    def store_stats_data
      File.open(stats_file_name, "w"){ |o| o.write(@data.to_yaml) }
    end

  end
end