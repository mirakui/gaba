require 'time'
require 'mechanize'

GABA_URL_BASE = 'https://my.gaba.jp'
LESSON_DETAIL_KEYWORDS_TRANSLATION = {
  '教材' => 'textbook',
  '長所・強み' => 'strength',
  'セクション' => 'section',
  '単語' => 'words',
  'フレーズ' => 'phrases',
  '発音' => 'pronunciation',
  '課題点' => 'problems',
}
CRAWL_INTERVAL = 1

def env(name)
  val = ENV[name]
  unless val
    raise "ENV['#{name}'] required"
  end
  val
end

def mechanize
  @mechanize ||= Mechanize.new
end

def login
  mechanize.get("#{GABA_URL_BASE}/auth/login")
  form = mechanize.page.forms.first
  form.field_with('username').value = env('GABA_ID')
  form.field_with('password').value = env('GABA_PASSWORD')
  page = form.submit
  if page.uri.path != "/home"
    raise "login failed with id=#{env('GABA_ID').inspect}"
  end
  page
end

def parse_lesson_page(page)
  items = []
  page.css('.lessonRecord').each do |record|
    item = {}
    item['instructor_name'] = record.css('.instructorName').text
    item['lesson_time'] = Time.parse(record.css('.lessonRecordHeader h2').text)
    record.css('.details li').each do |li|
      m = li.text.match(/\A\s*([^\s]+):(.*)\z/m)
      unless m
        raise "cannot parse as details: #{li.text.inspect}"
      end
      _key = m[1].strip
      key = LESSON_DETAIL_KEYWORDS_TRANSLATION[_key]
      unless key
        raise "unexpected detail keyword: #{_key.inspect}"
      end
      val = m[2].strip
      val.gsub!(/  +/, ' ')
      if %w(words phrases).include?(key)
        val = val.split('|').map(&:strip)
      end
      item[key] = val
    end
    items << item
  end
  pp items
end

def crawl_lesson_pages
  page = mechanize.get("#{GABA_URL_BASE}/lesson/lessonrecords/page/1")
  loop do
    parse_lesson_page(page)

    next_link = page.link_with(text: '»')
    if next_link
      sleep CRAWL_INTERVAL
      page = next_link.click
    else
      break
    end
  end
end

def main
  login
  crawl_lesson_pages
end

main
