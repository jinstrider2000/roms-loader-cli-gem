require_relative 'romloader/romloader_cli.rb'
require 'pry'

def run
  Dir.mkdir(File.join(Dir.home,"videogame_roms")) unless Dir.exist?(File.join(Dir.home,"videogame_roms"))
  RomloaderCli.new.start
end
