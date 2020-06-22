def moin2markdown(moin)

  convert_tables = proc do |s|
    chunks = s.each_line.chunk { |line| line.match? /^\s*\|\|.*\|\|\s*$/ }

    flattened = chunks.map do |is_table, lines|
      if is_table

        lines.map.with_index do |line,i|
          cols = line.scan(/(?<=\|\|)([^\|]+)(?=\|\|)/).flatten

          newline = cols.join(" | ")
          newline << " |" if cols.size == 1
          newline << "\n"

          if i == 0
            sep = cols.map { |col| "-" * col.size }.join("-|-") + "\n"

            if cols.all? { |col| col.match? /__.+__/ } # table has headers!
              [newline, sep]
            else
              empty_header = (["..."]*cols.size).join(" | ") + "\n"
              [empty_header, sep, newline]
            end
          else
            newline
          end
        end

      else
        lines
      end
    end.flatten

    flattened.join
  end

  markdown = moin.
    gsub(/^(={1,5}) (.+) =+$/) { |m| ("#" * $1.size ) + " " + $2 }. # headers
    gsub(/'''/, "__").                            # bolds
    gsub(/''/, "_").                              # italics
    gsub(/\{\{(?:attachment:)?(.+)\}\}/, "![](/_attachments/\\1)").  # images
    gsub(/\[\[(.+)\|(.+)\]\]/, "[\\2](\\1)").     # links w/ desc
    gsub(/\[\[(.+)\]\]/, "[\\1](\\1)").           # links w/o desc
    gsub(/^#acl .+$/, '').                        # remove ACLs
    gsub(/^<<TableOfContents.+$/, '').            # remove TOCs
    gsub(/^## page was renamed from .+$/, '').    # remove 'page was renamed'
    # TODO: use `html-renderer` to convert it to ANSI
    gsub(/^\{\{\{\n^#!raw\n(.+)\}\}\}$/m, "\\1"). # remove {{{#!raw}}}s
    # TODO: convert {{{\n#!highlight lang}}}s (2-phase: match {{{ }}}'s, then match first line inside)
    gsub(/\{\{\{\n?#!(?:highlight )?(\w+)\n(.+)\n\}\}\}$/m, "```\\1\n\\2\n```"). # convert {{{#!highlight lang }}} to ```lang ```
    gsub(/\{\{\{\n(.+)\n\}\}\}$/m, "```\n\\1\n```")  # convert {{{ }}} to ``` ```

  markdown = convert_tables[markdown]
end
