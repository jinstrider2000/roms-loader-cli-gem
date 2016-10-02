require_relative 'freeroms_scraper.rb'
require_relative 'game_rom.rb'
require_relative 'game_system.rb'
require_relative 'scraping_error/no_element_found.rb'
require 'pry'

class RomloaderCli

  def initialize
    GameSystem.create_from_collection(FreeromsScraper.system_scrape("http://freeroms.com"))
  end

  def start
    input_stack = []
    control_flow_level = 1

    puts "Thanks for using RomLoader, powered by freeroms.com!\nConnecting to freeroms.com and retrieving the system index...\n\n"
    while control_flow_level > 0 && GameSystem.all.size > 0
      case control_flow_level
      when 1
        list_systems
        input = input_prompt("Select a system (1-#{GameSystem.all.size}) [exit]:",1..GameSystem.all.size)
        if input == "exit"
          control_flow_level = 0
        else
          input_stack.unshift(input)
          control_flow_level += 1
        end
      when 2
        system = select_system(input_stack[0])
        list_system_index(system)
        input = input_prompt("Select a letter [back|exit]:", /[#{system.get_rom_indices.join.downcase}]/,control_flow_level)
        control_flow_level = flow_controller(input,control_flow_level,input_stack)
      when 3
        game_collection = select_game_collection_by_index(system,input_stack[0].upcase)
        if game_collection.empty?
          begin
            raise ScrapingError::NoElementFound.exception("Requested game index is currently unavailable. Try another one.")
          rescue
            control_flow_level -= 1
            input_stack.shift
          end
        else
          list_games(game_collection)
          input = input_prompt("Select a game (1-#{game_collection.size}) [back|exit]", 1..game_collection.size,control_flow_level)
          control_flow_level = flow_controller(input,control_flow_level,input_stack)
        end
      when 4
        game = select_game(game_collection,input_stack[0])
        display_rom_details(game)
        input = input_prompt("Download (y/n) [exit]:", /[yn]/)
        if input == 'y'
          download_rom(game)
        end
        input_stack.shift
        input == "exit" ? control_flow_level = 0 : control_flow_level -= 1
      end
    end

    if GameSystem.all.size > 0
      puts "Happy Gaming!"
    else
      raise ScrapingError::NoElementFound.exception("System index is currently unavailable. Exiting the program.")
    end
    
  end

  def flow_controller(input,control_flow_level,input_stack)
    if input == "exit"
      0
    elsif input == "back"
      input_stack.shift
      control_flow_level - 1
    else
      input_stack.unshift(input)
      control_flow_level + 1
    end
  end

  def list_systems
    GameSystem.all.each_with_index { |game_system, index| puts "#{index+1}. #{game_system.name}"}
    print "\n"
  end

  def select_system(index)
    GameSystem.all[index.to_i-1]
  end

  def list_system_index(selected_system)
    puts "#{selected_system.name} index:"
    selected_system.get_rom_indices.each {|letter| print letter + " "}
    puts "\n\n"
  end

  def select_game_collection_by_index(system, letter)
    puts "Loading roms, this could take a while...\n"
    games_list = system.get_roms_by_letter(letter)
    games_list ||= system.add_roms_to_collection_by_letter(letter,GameRom.create_collection(FreeromsScraper.rom_scrape(system.get_rom_index_url(letter))))
  end

  def list_games(games)
    games.each_with_index {|game,index| puts "#{index+1}. #{game.name}"}
    print "\n"
  end

  def select_game(game_collection,index)
    game_collection[index.to_i-1]
  end

  def display_rom_details(game)
    puts "Rom details:"
    puts "#{game.name} | File size: #{game.size} | File type: #{game.file_ext}"
    puts "NOTE: To uncompress 7-Zip (.7z) files, please download a system compatible version at http://www.7-zip.org/download.html" if game.file_ext == ".7z"
    print "\n"
  end

  def input_prompt(message,accepted_input,control_flow_level=nil)
    valid = false
    until valid 
      print message + " "
      input = gets.chomp.strip.downcase
      if accepted_input.class == Regexp && accepted_input.match(input)
        valid = true
      elsif accepted_input.class == Range && /\A\d+\Z/.match(input) && accepted_input.include?(input.to_i)
        valid = true
      elsif input == "exit" || (input == "back" &&  control_flow_level && control_flow_level.between?(2,3))
        valid = true
      end
    end
    print "\n"
    input
  end

  def download_rom(game)
    puts "Downloading #{game.name} (#{game.size})..."
    result = Dir.chdir(File.join(Dir.home,"videogame_roms")) do
      system("curl -Og# \"#{game.download_url}\"")
    end
    result ? puts("Finished downloading to #{File.join(Dir.home,"videogame_roms")}.\n") : puts("An error occured, the rom couldn't be downloaded.\n")
    sleep 3
    puts "\n"
  end
  
end

