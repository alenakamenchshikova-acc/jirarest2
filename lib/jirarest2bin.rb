#    Copyright (C) 2012 Cyril Bitterich
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#This file keeps the require for the shell UI scripts together

require "highline/import"
require "jirarest2"
require "optparse"
require "ostruct"
require "jirarest2/madbitconfig"
require "uri"


module Jirarest2Bin
  # Checks for the minimum jira version (1.9.1)
  def self.check_ruby_version
    if RUBY_VERSION < "1.9"
      puts "Sorry, I need ruby 1.9.1 or higher!"
      exit 1
    end
  end
  

  # write the config file for the conenction to jira
  # @param [Openstruct] scriptopts Openstruct object that contains all the paramters needed to create the config file
  def self.write_configfile(scriptopts)
    text = Hash.new
    if scriptopts.url.nil? then
      text["#URL"] = "https://host.domain.com:port/path/"
    else
      text["URL"] = "#{scriptopts.url}"
    end
    if scriptopts.username.nil? then
      text["#username"] = "USERNAME"
    else
      text["username"] = "#{scriptopts.username}"
    end
    text["#password"] = "Your!PassW0rd"
    begin
      if scriptopts.writeconf == :forcewrite then
        MadbitConfig::write_configfile(scriptopts.configfile,text,:force)
      else
        MadbitConfig::write_configfile(scriptopts.configfile,text)
      end
      puts "Configfile written to #{scriptopts.configfile}. Exiting."
      exit 0
    rescue MadbitConfig::FileExistsException => e
      puts "Configfile #{e} already exists. Use \"--force-write-config-file\" to replace."
      exit 1
    end
  end
  
  # Get the password from an interactive shell
  # @param [String] username The Username to show
  # @return [String] the password as read from the command line
  def self.get_password(username)
    password = ask("Enter your password for user \"#{username}\":  ") { |q| 
      q.echo = "*" 
    }
    return password
  end

  # Gather all the credentials and build the credentials file
  # @param [Openstruct] scriptopts The Openstruct object that contains all the options relevant for the script
  # @return [Credentials] a credentials object
  def self.get_credentials(scriptopts)
    filefail = false
    begin
      fileconf = MadbitConfig::read_configfile(scriptopts.configfile)
      # We don't want to set the Values from the configfile if we have them already set.
      scriptopts.username = fileconf["username"] if ( scriptopts.username.nil? && fileconf["username"] )
      scriptopts.pass = fileconf["password"] if ( scriptopts.pass.nil? && fileconf["password"] )
      if ( scriptopts.url.nil? && fileconf["URL"] ) then
        scriptopts.url = fileconf["URL"] 
      end
    rescue IOError => e
      puts e
      filefail = false
    end
    scriptopts.url = scriptopts.url + "/rest/api/2/"
    
    if scriptopts.pass.nil? && !( scriptopts.username.nil?)  then
      scriptopts.pass = Jirarest2Bin::get_password(scriptopts.username)
    end
    
    missing = Array.new
    missing << "URL"  if scriptopts.url.nil?
    missing << "username" if  scriptopts.username.nil?
    if  missing != [] then
      puts "Missing essential parameter(s) #{missing.join(",")}. Exiting..."
      exit 1
    else
      return Credentials.new(scriptopts.url, scriptopts.username, scriptopts.pass)
    end
  end # get_credentials


  # If there is already a connection known returns that connection. If not or if the parameter is true it tries to create a new Connect object
  # @param [Openstruct] scriptopts The Openstruct object that contains all the options relevant for the script
  # @param [Connect] connection An existing connection. Will be nil the first time we use it.
  # @param [Boolean] reconnect Loose an existing connection and build a new one
  # @return [Connection] A connection object that contains all the parameters needed to connect to JIRA(tm)
  def self.get_connection(scriptopts, connection, reconnect = false)
    if ! connection || reconnect then
      begin
        connection = Connect.new(get_credentials(scriptopts))
        connection.heal_uri! # We want to be sure so we try to heal the connection_url if possible
        return connection
      rescue Jirarest2::CouldNotHealURIError => e
        puts "REST API not found at #{e.to_s}"
        exit 3
      end
    else
      return connection
    end
  end # get_connection
  
end
