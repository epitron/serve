class MemPrinter
  # size     total program size (pages)            (same as VmSize in status)
  # resident size of memory portions (pages)       (same as VmRSS in status)
  # shared   number of pages that are shared       (i.e. backed by a file, same
  #                                           as RssFile+RssShmem in status)
  # trs      number of pages that are 'code'       (not including libs; broken,
  #                                           includes data segment)
  # lrs      number of pages of library            (always 0 on 2.6)
  # drs      number of pages of data/stack         (including libs; broken,
  #                                           includes library text)
  # dt       number of dirty pages                 (always 0 on 2.6)
  FIELDS      = %w[total_pages resident_pages mmapped_pages code_pages lib_pages data_pages dirty_pages]
  FIELD_WIDTH = FIELDS.map(&:size).max

  using Module.new {
    refine Numeric do
      def commatize(char=",")
        str = self.is_a?(BigDecimal) ? to_s("F") : to_s

        int, frac = str.split(".")
        int = int.gsub /(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/, "\\1#{char}\\2"

        frac ? "#{int}.#{frac}" : int
      end
    end
  }

  def heap_stats
    data           = File.read("/proc/#{$$}/statm").split.map(&:to_i)
    $start_data  ||= data
    diffs          = data.zip($start_data).map { |a,b| a - b }

    FIELDS.zip(data.zip(diffs))
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    result = @app.call(env)

    output = ["[heap stats]"]
    heap_stats.each do |k,vs|
      output << "  #{k.rjust(FIELD_WIDTH)}: #{vs[0].commatize} (change: #{vs[1].commatize})"
    end
    $stderr.puts(output.join("\n"))

    result
  end

end