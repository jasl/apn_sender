# Modified slightly from delayed_job's delayed/command.rb
require 'rubygems'
require 'daemons'
require 'optparse'

module APN
  class SenderDaemon
    
    def initialize(args)
      @options = {:quiet => true, :worker_count => 1, :environment => :development}
      
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options] start|stop|restart|run"

        opts.on('-h', '--help', 'Show this message') do
          puts opts
          exit 1
        end
        opts.on('-e', '--environment=NAME', 'Specifies the environment to run this apn_sender under ([development]/production).') do |e|
          @options[:environment] = e
        end
        opts.on('--cert-path=NAME', '--certificate-path=NAME', 'Path to directory containing apn .pem certificates.') do |path|
          @options[:cert_path] = path
        end
        opts.on('-n', '--number_of_workers=WORKERS', "Number of unique workers to spawn") do |worker_count|
          @options[:worker_count] = worker_count.to_i rescue 1
        end
        opts.on('-v', '--verbose', "Turn on verbose mode") do
          @options[:verbose] = true
        end
        opts.on('-V', '--very_verbose', "Turn on very verbose mode") do
          @options[:very_verbose] = true
        end
        opts.on('-d', '--delay=D', "Delay between rounds of work (seconds)") do |d|
          @options[:delay] = d
        end
      end
      
      # If no arguments, give help screen
      @args = optparse.parse!(args.empty? ? ['-h'] : args)
      
      puts "OPTS: #{@options.inspect}"
    end
  
    def daemonize
      @options[:worker_count].times do |worker_index|
        process_name = @options[:worker_count] == 1 ? "apn_sender" : "apn_sender.#{worker_index}"
        Daemons.run_proc(process_name, :dir => "#{::RAILS_ROOT}/tmp/pids", :dir_mode => :normal, :ARGV => @args) do |*args|
          run process_name
        end
      end
    end
    
    def run(worker_name = nil)
      Dir.chdir(::RAILS_ROOT)
      require File.join(::RAILS_ROOT, 'config', 'environment')
      
      # Replace the default logger
      logger = Logger.new(File.join(::RAILS_ROOT, 'log', 'apn_sender.log'))
      logger.level = ActiveRecord::Base.logger.level
      ActiveRecord::Base.logger = logger
      ActiveRecord::Base.clear_active_connections!
      
      worker = APN::Sender.new(@options)
      worker.logger = logger
      worker.verbose = @options[:verbose]
      worker.very_verbose = @options[:very_verbose]
      worker.work(@options[:delay])
    rescue => e
      logger.fatal(e) if logger.respond_to?(:fatal)
      STDERR.puts e.message
      exit 1
    end
    
  end
end