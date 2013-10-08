class ClipBook

  class Clip

    attr_reader :date, :content

    def initialize(date, str)
      @date = date
      @content = str
    end

    def self.parse(header, str)
      require 'date'

      date = DateTime.parse(header.split("\n").first)
      content = str

      Clip.new(date, content)
    end

    def hash
      require 'digest/md5'
      h1 = Digest::MD5.hexdigest(@content)
      h2 = Digest::MD5.hexdigest(@date.to_s)
      Digest::MD5.hexdigest h1 + h2
    end

  end

  def initialize(clips)
    @clips = clips
  end

  def self.parse(str)
    clips = []

    delimiter_regexp = /(^.*$\n^[-]{80}$\n)/

    things = str.split(delimiter_regexp)

    current_header = nil

    things.shift

    things.each do |t|
      if t =~ delimiter_regexp
        if current_header
          clips << Clip.parse(current_header, '')
          puts "Warning: Committing null. "
        else
          current_header = t
        end
      else
        if !current_header
          puts 'Warning: Null'
        else
          clips << Clip.parse(current_header, t)
          current_header = nil
        end
      end
    end

    ClipBook.new clips
  end

  def append(path)
    require 'sqlite3'
    require 'fileutils'

    FileUtils.mkdir_p File.dirname(path)

    db = nil

    if File.exists?(path)
      db = SQLite3::Database.open path
    else
      db = SQLite3::Database.new path, {}
    end

    db.execute "CREATE TABLE IF NOT EXISTS clips(id INTEGER PRIMARY KEY AUTOINCREMENT, datetime TEXT, content TEXT, hash TEXT)"

    count = 0
    skipped = 0

    @clips.each do |c|
      stm = db.prepare "SELECT * FROM clips WHERE hash LIKE \"#{c.hash}\""
      rs = stm.execute

      if rs.count > 0
        skipped += 1
      else
        db.execute("INSERT INTO clips(datetime, content, hash) VALUES (?, ?, ?)", [c.date.to_s, c.content, c.hash])
        count += 1
      end

      stm.close if stm
    end

    puts "Committed #{count}, skipped #{skipped}. "

    db.close
  end
end
