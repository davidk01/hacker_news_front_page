require 'bundler/setup'
require 'scraperwiki'
require 'nokogiri'

# title, url, points, author, comments
db = SQLite3::Database.new('data.sqlite')
db.execute <<-SQL
  create table if not exists data
   (title text primary key on conflict replace,
     url text not null,
     points integer not null,
     author text not null,
     comments integer not null);
SQL

# Grab a few pages
db_data = ['https://news.ycombinator.com/', 
 'https://news.ycombinator.com/news?p=2',
 'https://news.ycombinator.com/news?p=3',
 'https://news.ycombinator.com/news?p=4'].flat_map do |page|
   frontpage = ScraperWiki.scrape(page)
   frontpage_html = Nokogiri::HTML(frontpage)
   things = frontpage_html.css('tr.athing')
   # Convert to hash maps with proper data
   db_datas = things.map do |element|
     maintext = element.css('td.title a').first
     title, url = maintext.text, maintext['href']
     subtext = element.next.css('td.subtext').first
     # If there are no points in subtext then assume job post and skip
     if subtext.text !~ /points/
       next
     end
     points = subtext.css('span').first.text.match(/(\d+)/)[1].to_i
     author = subtext.css('a')[0].text
     # There is a special case for comments. When there are no comments there is just 'discuss'
     if subtext.css('a')[2].text =~ /discuss/
       comments = 0
     else
       comments = subtext.css('a')[2].text.match(/(\d+)/)[1].to_i
     end
     db_item = {
       'title' => title, 
       'url' => url, 
       'points' => points, 
       'author' => author, 
       'comments' => comments
     }
   end
 end

 # Filter out any 'nil' elements because of skips and special cases
 db_data.reject! {|element| element.nil?}

 # Insert into database
 db_data.each do |data_item|
   db.execute('insert into data (title, url, points, author, comments) values ' + 
              '(:title, :url, :points, :author, :comments)', data_item)
 end
