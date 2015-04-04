require "ruby-ddp-client/version"
require 'faye/websocket'
require 'json'


class RubyDdp::Client < Faye::WebSocket::Client
  attr_accessor :onconnect
  attr_accessor :collections
  
  def initialize(host, port = 3000, path = 'websocket')
    super("http://#{host}:#{port}/#{path}")
    self.init_event_handlers()
    
    @_callbacks = {}
    @_next_id = 0
    @collections = {}
    @observe_callbacks = {}
  end
  
  def connect
    dosend(:msg => :connect, :version => '1', :support => ['1'])
  end
  
  def call(method, params = [], &blk)
    id = self.next_id()
    self.dosend(:msg => 'method', :id => id, :method => method, :params => params)
    @_callbacks[id] = blk
  end
  
  def subscribe(name, params, &blk)
    id = self.next_id()
    self.dosend(:msg => 'sub', :id => id, :name => name, :params => params)
    @_callbacks[id] = blk
  end

  def observe(collection_name, events, &callback)
    Array(events).each do |event|
      @observe_callbacks[event] ||= {}
      puts "adding callback for event '#{event}' on collection '#{collection_name}'"
      @observe_callbacks[event][collection_name] = callback
    end
  end

protected
  def next_id
    (@_next_id += 1).to_s
  end
  
  def dosend(data)
    self.send(data.to_json)
  end
  
  def init_event_handlers
    # event handlers
    self.onopen = lambda do |event|
      self.connect()
    end

    self.onmessage = lambda do |event|
      data = JSON.parse(event.data)
      puts data # Debug output
      if data.has_key?('msg')
        
        # TODO: 'error', 'nosub'
        # TODO -- method acks <- not sure exactly what the point is here
        
        case(data['msg'])
        when 'connected'
          self.onconnect.call(event)
        
        # collections
        when 'added', 'changed'
          name = data['collection']
          id = data['id']
          @collections[name] ||= {}
          @collections[name][id] ||= {}
          
          if data['fields'] # might not be the case, e.g., if a collection was added
            data['fields'].each do |key, value|
              @collections[name][id][key] = value
            end
          end

          if @observe_callbacks[data['msg']] && @observe_callbacks[data['msg']][name]
            @observe_callbacks[data['msg']][name].call id, data['fields']
          end

        when 'data'
          if data.has_key?('collection')
            name = data['collection']
            id = data['id']
            @collections[name] ||= {}
            @collections[name][id] ||= {}
          
            if data.has_key?('set')
              data['set'].each do |key, value|
                @collections[name][id][key] = value
              end
            end
            if data.has_key?('unset')
              data['unset'].each do |key|
                @collections[name][id].delete(key)
              end
            end
          end
          
        # method callbacks
        when 'result'
          cb = @_callbacks[data['id']]
          cb.call(data['error'], data['result']) if cb

        # subscription ready
        when 'ready'
          data['subs'].each do |id|
            cb = @_callbacks[id]
            cb.call() if cb
          end
        end
      end
    end

    self.onclose = lambda do |event|
    end
  end
end
