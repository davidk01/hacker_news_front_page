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
   # these are the elements that can contains titles and links
   things = frontpage_html.css('tr.athing')
   # now for each element extract the parts we want to scrape
   db_datas = things.map do |element|
     # element that contains title and link
     maintext = element.css('td.title a').first
     # the text and the associated link
     title, url = maintext.text, maintext['href']
     # this is the element that contains author, points, etc.
     # we just want the score which is the first element
     subtext = element.next.css('td.subtext').first
     # If there are no points in subtext then assume job post and skip
     if subtext.text !~ /points/
       puts "No poits. Assuming job post: #{title}"
       next
     end
     # now try to actually extract the points and author
     points = subtext.css('span').first.text.match(/(\d+)/)[1].to_i
     # author
     author = subtext.css('a')[0].text
     # the last element is the comment count which we also want
     # there is a special case for comments. When there are no comments there is just 'discuss'
     if subtext.css('a')[-1].text =~ /discuss/
       puts "No comments yet for this entry: #{title}"
       comments = 0
     else
       comments = subtext.css('a')[-1].text.match(/(\d+)/)[1].to_i
       puts "Found some comments: #{title}, #{comments}"
     end
     puts "Creating DB item"
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
puts "Adding #{db_data.length} items to db"

 # Insert into database
 db_data.each do |data_item|
   db.execute('insert into data (title, url, points, author, comments) values ' + 
              '(:title, :url, :points, :author, :comments)', data_item)
 end
