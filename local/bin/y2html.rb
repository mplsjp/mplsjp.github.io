#!/usr/bin/env ruby
# coding: utf-8
require 'rubygems'
require 'yaml'
require 'ostruct'
require 'pp'

# リスト形式のテーマ
module ListedTableTheme
  module_function

  @indent = 0

  # 渡された obj を出力します。インデントの指定がある場合は
  # それに従ってインデントを行います。
  #
  # ==== Parameters
  # _obj_:: 出力するオブジェクト。文字列または文字列を格納する配列。
  # _indent_:: 左インデントの幅。省略時はインデントを行いません。
  #
  # ==== Returns
  # void
  def disp(obj, indent = nil)
    indent ||= @indent

    indent_str = ' ' * indent
    obj = obj.split(/\n/) unless obj.respond_to? :each

    obj.each do |line|
      line.chomp!
      puts "#{indent_str}#{line}"
    end
  end

  # あるセッション内の発表項目を1件出力します。
  #
  # ==== Parameters
  # _session_:: そのセッションの情報が入っているハッシュ
  # _item_:: その項目の情報が入っているハッシュ
  # _index_:: その項目のインデックスを示します (0 から開始)
  #
  # ==== Returns
  # void
  def proc_item(session, item, index, indent = 10)
    out = []
    s = OpenStruct.new(session)
    i = OpenStruct.new(item)
    i.iid = "#{s.sid}-%02d" % index

    if i.presenter == '発表者調整中'
      i.presenter = '<i>' + i.presenter + '</i>'
    end
    i.title.gsub!(/__br__/, '<br />')

    material = "&nbsp;"
    case i.file
    when /\.[a-zA-Z0-9]+$/
      material = %{(<a href="presentations/#{i.file}">講演資料</a>)}
    when String
      material = i.file
    end
    abstract = i.abstract ? i.abstract : ''

    if i.description
      out << %{<li>}
      out << %{  <ul class="presentation" id="#{i.iid}">}
      out << %{    <li class="presentation-title" id="#{i.iid}-presentation-title">#{i.title}</li>}
      out << %{    <li class="material" id="#{i.iid}-material">#{material}</li>}
      out << %{    <li class="presenter" id="#{i.iid}-presenter">#{i.presenter}</li>}
      out << %{    <li class="presenter-company" id="#{i.iid}-presenter-company">#{i.company}</li>}
      out << %{    <li class="abstract">#{i.description}</li>}
      out << %{  </ul>}
      out << %{</li>}
    else
      out << %{<li>}
      out << %{  <ul class="presentation" id="#{i.iid}">}
      out << %{    <li class="presentation-title" id="#{i.iid}-presentation-title">#{i.title}</li>}
      out << %{    <li class="material" id="#{i.iid}-material">#{material}</li>}

      if i.presenter.kind_of? Array
        i.presenter.each_with_index do |person, idx|
          material = ''
          case person['file']
          when /\.[a-zA-Z0-9]+$/
            material = %{(<a href="presentations/#{person['file']}">講演資料</a>)}
          when String
            material = person['file']
          end

          out << %{    <li class="presenter" id="#{i.iid}-presenter#{idx}">#{person['presenter']}</li>}
          out << %{    <li class="presenter-company" id="#{i.iid}-presenter#{idx}-company">(#{person['company']})</li>}
          out << %{    <li class="material" id="#{i.iid}-material">#{material}</li>}
        end
      else
        out << %{    <li class="presenter" id="#{i.iid}-presenter">#{i.presenter}</li>}
        out << %{    <li class="presenter-company" id="#{i.iid}-presenter-company">(#{i.company})</li>}
      end
      out << %{    <li class="abstract" id="#{i.iid}-abstract">#{abstract}</li>}
      out << %{  </ul>}
      out << %{</li>}
    end

    disp(out, indent)
  end

  # あるセッションの情報を出力します。
  #==== Parameters
  # [+session+] そのセッションの情報が入っているハッシュ
  # [+index+] その項目のインデックスを示します (0 から開始)
  #==== Returns
  # void
  def proc_session(session, index)
    s = OpenStruct.new(session)
    s.sid = session['sid'] = "sid-%02d-#{s.session_id}" % index

    s.style = index.even? ? "even-row" : "odd-row"

    # セクションヘッダ
    if s.session
      puts %{    <!-- #{s.time}: #{s.session} -->}
    else
      puts %{    <!-- #{s.time} -->}
    end

    puts %{    <tr id="#{s.sid}" class="#{s.style}">}
    puts %{      <td class="time">}
    puts %{        <div class="session-time">#{s.time}</div>}
    puts %{        <div class="session-title-abbr">#{s.session_abbr}</div>} if s.session_abbr
    puts %{      </td>}
    puts %{      <td class="program">}
    puts %{        <ol>}

    # セッションタイトル
    if s.session
      puts %{          <li>}
      puts %{            <div class="session-title">#{s.session}</div>}
      puts %{          </li>}
    end

    # 各項目を表示
    if s.items
      count = s.items.count
      s.items.each_with_index do |item, item_index|
        proc_item(session, item, item_index)
        count = nil
      end
    elsif s.content
      puts %{          <li class="content" id="#{s.sid}-00">#{s.content}</li>}
    else
      # 説明だけを表示
      puts %{          <li class="description" id="#{s.sid}-00">#{s.description}</li>}
    end

    # セクションフッタ
    puts %{        </ol>}
    puts %{      </td>}
    puts %{    </tr>}
  end

  def include_programs(dict)
    dict.each_with_index do |session, index|
      proc_session(session, index)
    end
  end

  def include_program_table(dict)
    puts <<-_EOD_
  <table id="program-table" class="program-table"
      summary="MPLS Japanプログラム">
    <thead>
      <tr>
        <th class="time">時間</th>
        <th class="program">内容</th>
      </tr>
    </thead>
    <tbody>
    _EOD_

    include_programs(dict)

    puts <<-_EOD_
    </tbody>
  </table>
    _EOD_
  end

  #
  # 実行委員会メンバーのリスト出力
  #

  def proc_committee(dict, indent)
    ['representative', 'chair', 'member'].each do |title_id|
      dict.select {|x| x['title_id'] == title_id } \
        .sort {|a, b| a['kana'] <=> b['kana'] } \
        .each_with_index \
      do |item, index|
        title = (index == 0) ? item['title'] : '&nbsp;'
        cname = (index == 0) ? ' labeled' : ''

        disp(%{<tr>}, indent)
        disp(%{<th class="title#{cname}">#{title}</th>}, indent + 2)
        disp(%{<td class="name">#{item['name']}</td>}, indent + 2)
        disp(%{<td class="org">#{item['org']}</td>}, indent + 2)
        disp(%{</tr>}, indent)
      end
    end
  end

  def include_committee(dict)
    indent = 0  # base indent for this block.
    puts <<-_EOD_
<table id="committee-table" class="committee-table"
    summary="MPLS Japan実行委員会">
  <tbody>
    _EOD_

    proc_committee(dict, indent + 4)

    puts <<-_EOD_
  </tbody>
</table>
    _EOD_
  end
end

@dic = YAML.load_file 'program.yaml'
@committee = YAML.load_file 'committee.yaml'
@theme = ListedTableTheme
while line = gets
  case line
  when /#include_programs#/
    @theme.include_programs(@dic)
  when /#include_program_table#/
    @theme.include_program_table(@dic)
  when /#include_committee#/
    @theme.include_committee(@committee)
  else
    print line
  end
end
__END__
