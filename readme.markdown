Ruby DDP Client
===============

A minimal DDP client for ruby. Uses [faye-websocket](https://github.com/faye/faye-websocket-ruby), an EventMachine based websocket client.

##Example usage

```ruby
posts = nil
EM.run do
  ddp_client = RubyDdp::Client.new('localhost', 3000)

  ddp_client.onconnect = lambda do |event|
    ddp_client.subscribe('posts', [post_ids]) do |result|
      posts = ddp_client.collections['posts']
      EM.stop_event_loop
    end
  end
end
posts
```

More info about the protocol can be found [here](https://github.com/meteor/meteor/blob/master/packages/livedata/DDP.md).
