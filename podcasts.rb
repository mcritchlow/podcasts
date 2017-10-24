require 'nokogiri'
require 'open-uri'
require 'yaml'

# An episode is a simple struct
Episode = Struct.new(:title, :url, :pub_date) do
  def filename
    formatted_title + '.' + extension
  end

  def formatted_title
    title.strip.tr(' ', '_').downcase
  end

  def extension
    url.scan(/ogg|mp3/).last
  end
end

# A single rss podcast subscription
class Subscription
  attr_reader :title, :feed_url, :directory
  def initialize(title, feed_url, directory)
    @title = title
    @feed_url = feed_url
    @directory = directory

    confirm_directory_exists
  end

  def confirm_directory_exists
    Dir.mkdir(directory) unless Dir.exist?(directory)
  end

  def find_latest_episode
    feed_doc = Nokogiri.parse(open(feed_url))

    title = feed_doc.at('item title').text
    pub_date = feed_doc.at('item pubdate').text
    url = feed_doc.at('item enclosure').attr('url')
    episode = Episode.new(title, url, pub_date)

    download_episode(episode)
  rescue => e
    puts "Oops, ran into #{e}. Try again?"
  end

  def download_episode(episode)
    download_location = File.join(directory, episode.filename)
    if File.exist? download_location
      puts "You already have #{episode.title}, skipping!"
      return
    end

    puts "Latest #{title} episode is: #{episode.title} posted #{episode.pub_date}"
    puts 'Would you like to download it? [y/n]'
    STDOUT.flush
    response = STDIN.gets.chomp
    return unless response.eql? 'y'

    Kernel.system "curl -L #{episode.url} --output #{download_location}"
  end
end

# Primary class for managing podcast subscriptions
class Podcasts
  attr_reader :subscriptions
  attr_reader :podcast_home

  def initialize
    @subscriptions = YAML.safe_load(File.read('config.yml'))
    @podcast_home = File.join(Dir.home, 'Music', 'podcasts')

    confirm_podcast_home_directory_exists
  end

  def run
    subscriptions.each do |title, feed_url|
      directory = File.join(podcast_home, title)
      subscription = Subscription.new(title,
                                      feed_url,
                                      directory)

      puts "Checking #{title} for new episode"
      subscription.find_latest_episode
    end

    update_mpc_playlist if Kernel.test('e', '/usr/bin/mpc')
  end

  def update_mpc_playlist
    puts 'Updating mpc playlist with new content..'
    Kernel.system 'mpc update --wait'
    Kernel.system 'mpc ls | mpc add'
  end

  def confirm_podcast_home_directory_exists
    Dir.mkdir(podcast_home) unless Dir.exist?(podcast_home)
  end
end

Podcasts.new.run
