require 'net/irc'
require 'mongo'
require 'yaml'

class Prowl < Net::IRC::Client

  def initialize(host, port, opts={})
    opts.merge!(YAML.load_file('prowl.yaml'))
    super(host || opts['host'], port || opts['port'], opts)

    @db = Mongo::Connection.new(ENV['DATABASE_URL'] || 'localhost', ENV['DATABASE_PORT'] || 27017).db(@opts.db)
  end

  def on_rpl_welcome(m)
    @log.debug "ON_RPL_WELCOME #{m.inspect}"
    post JOIN, @opts.join_channels.join(',')
  end

  def on_privmsg(m)
    @log.debug "ON_PRIVMSG #{m.inspect}"
    # regular channel message
    #<Net::IRC::Message:0x4564064 prefix:jdrowell!~jdrowell@189-19-127-17.dsl.telesp.net.br command:PRIVMSG params:["#nosqlbr", "hi there"]>
    # private message /MSG
    #<Net::IRC::Message:0x4dd2fc0 prefix:jdrowell!~jdrowell@189-19-127-17.dsl.telesp.net.br command:PRIVMSG params:["prowlbot", "this is a secret"]>
    nick, user = m.prefix.split('!')
    is_public = m[0][0] == '#'
    channel = m[0] if is_public
    to_me = !(m[1] =~ /^prowlbot, (.*)/).nil? 
    if is_public && to_me
      post PRIVMSG, channel, "#{nick}, lolo to #{$1}"
    end
    if !is_public
      post PRIVMSG, nick, "shhhh, the walls have ears here!"
    end
    # log if it's public
    if is_public
      data = { :time => Time.now.utc, :nick => nick, :message => m[1] }
      @log.debug "MONGO #{data.inspect}"
      @db[channel].insert(data)
    end
  end

  def on_nickserv(m)
    @log.debug "ON_NICKSERV #{m.inspect}"
    #<Net::IRC::Message:0x5037d54 prefix:NickServ!NickServ@services. command:NOTICE params:["prowlbot", "This nickname is registered. Please choose a different nickname, or identify via \x02/msg NickServ identify <password>\x02."]>
    if m.params[1] =~ /NickServ identify/
      post PRIVMSG, "NickServ", "identify #{@opts.nickserv_pass}"
    end
  end

  def on_notice(m)
    return on_nickserv(m) if m.prefix == "NickServ!NickServ@services."
    @log.debug "ON_NOTICE #{m.inspect}"
  end

end

bot = Prowl.new(nil, nil)
bot.start

# #riak #redis #nosqlbr #mongodb #elasticsearch
# show logs: db['#mongodb'].find.each { |m| puts "#{m['time'].to_s[11..18]} #{m['nick'].ljust(14)} #{m['message']}" }
#
          

