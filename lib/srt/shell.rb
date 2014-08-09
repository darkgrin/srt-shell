require 'srt/shell/version'
require 'srt'
require 'srt/patches'

module SRT
  class Shell
    SAVE_HOOK_FILE = ::File.expand_path('~/.srt_shell_hook')
    USAGE_MSG = <<USAGE
Usage: #{$0} [SRT_FILENAME]
    Commands:
        EX: load 'SRT_FILENAME'
        EX: interval 90
        EX: upshift|u 50 5000
        EX: forward|f 50 5000
        EX: remove 50
        EX: save
        EX: show|s 50
        EX: search TERM
        EX: help|h
        EX: exit
USAGE

    def initialize(path = nil, save_hook=SAVE_HOOK_FILE)
      @file = nil
      @path = nil
      load_path(path) if path
      @save_hook = ::File.exists?(save_hook) ? save_hook : nil
    end

    def load_path(path)
      path = ::File.expand_path(path)
      @path = path
      @file = SRT::File.parse(::File.open(path))
      self
    end

    def show(index)
      check_index(index)
      puts @file.lines[index - 1].to_s + "\n"
    rescue IndexError => e
      puts e.message
    end

    def timeshift(index, timecode)
      check_index(index)
      if time = Parser.timespan(timecode)
        @file.lines[index-1..-1].each do |l|
          l.start_time += time
          l.end_time += time
        end
      else
        puts "Invalid timeshift input (#{index}, #{timecode})"
      end
    rescue IndexError => e
      puts e.message
    end

    def rewind(index, time)
      timeshift(index, "-#{time}ms")
    end

    def forward(index, time)
      timeshift(index, "+#{time}ms")
    end

    def scan_interval(input_time)
      unless time = Parser.timespan("#{input_time}ms")
        puts "Invalid time used #{input_time}"
        return
      end
      end_time = 0
      result = []
      @file.lines.each do |l|
        interval = l.start_time - end_time
        result << l.to_s if interval >= time
        end_time = l.end_time
      end
      puts result.join("\n")
    end

    def remove(index)
      check_index(index)
      index -= 1
      @file.lines.delete_at(index)
      @file.lines[index..-1].each do |l|
        l.sequence -= 1
      end
    rescue IndexError => e
      puts e.message
    end

    def search(term)
      result = []
      @file.lines.each do |l|
        if l.text.find { |t| t[term] }
          result << l.to_s
        end
      end
      puts result.join("\n") + "\n"
    end

    def show_all
      puts @file
    end

    def save(path=@path)
      ::File.open(path, 'w') do |f|
        f.print @file.to_s.split("\n").join("\r\n"), "\r\n\r\n"
      end
      if @save_hook
        output = `sh #{@save_hook}`
        puts output unless output.empty?
      end
    end

    def eval_command(cmd)
      case cmd
      when /^\s*(?:help|h)\s*$/
        puts USAGE_MSG
        return
      when /^\s*exit\s*$/
        exit 0
      when /^\s*load\s+\'?([^']+)\'?\s*$/
        load_path($1)
        return
      end

      if @file
        case cmd
        when /^\s*(?:show|s)\s+(\d+)\s*$/
          show($1.to_i)
        when /^\s*(?:showall)\s*$/
          show_all
        when /^\s*interval\s+(\d+)\s*$/
          scan_interval($1.to_i)
        when /^\s*(?:u|rewind)\s+(\d+)\s+(\d+)\s*$/
          rewind($1.to_i, $2.to_i)
        when /^\s*(?:f|forward)\s+(\d+)\s+(\d+)\s*$/
          forward($1.to_i, $2.to_i)
        when /^\s*(?:remove)\s+(\d+)\s*$/
          remove($1.to_i)
        when /^\s*save\s*$/
          save
        when /^\s*search\s*(.*)$/
          search($1)
        else
          puts "Invalid command"
        end
      else
        puts "File is not loaded. Load a file using the 'load' command"
      end
    end

    private

    def check_index(index)
      if index < 1
        raise IndexError, "Invalid index given, index must be more than 0"
      end
    end
  end
end
