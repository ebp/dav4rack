---
title: DAV4Rack - Web Authoring for Rack
---

DAV4Rack is a framework for providing WebDAV via Rack allowing content
authoring over HTTP. It is based off the [original RackDAV framework][1]
to provide better Resource support for building customized WebDAV resources
completely abstracted from the filesystem. Support for authentication and
locking has been added as well as a move from REXML to Nokogiri. Enjoy!

## Install

### Via RubyGems

    gem install dav4rack

## Quickstart

If you just want to share a folder over WebDAV, you can just start a
simple server with:

    dav4rack

This will start a Mongrel or WEBrick server on port 3000, which you can connect
to without authentication. The simple file resource allows very basic authentication
which is used for an example. To enable it:

    dav4rack --username=user --password=pass

## Rack Handler

Using DAV4Rack within a rack application is pretty simple. A very slim
rackup script would look something like this:

  require 'rubygems'
  require 'dav4rack'
  
  use Rack::CommonLogger
  run DAV4Rack::Handler.new(:root => '/path/to/public/fileshare')
  
This will use the included FileResource and set the share path. However,
DAV4Rack has some nifty little extras that can be enabled in the rackup script. First,
an example of how to use a custom resource:

  run DAV4Rack::Handler.new(:resource_class => CustomResource, :custom => 'options', :passed => 'to resource')
  
Next, lets venture into mapping a path for our WebDAV access. In this example, we 
will use default FileResource like in the first example, but instead of connecting
directly to the host, we will have to connect to: http://host/webdav/share/

  require 'rubygems'
  require 'dav4rack'
  
  use Rack::CommonLogger
  
  app = Rack::Builder.new{
    map '/webdav/share/' do
      run DAV4Rack::Handler.new(:root => '/path/to/public/fileshare', :root_uri_path => '/webdav/share/')
    end
  }.to_app
  run app
  
Aside from the #map block, notice the new option passed to the Handler's initialization, :root_uri_path. When
DAV4Rack receives a request, it will automatically convert the request to the proper path and pass it to
the resource.

Another tool available when building the rackup script is the Interceptor. The Interceptor's job is  to simply
intecept WebDAV requests received up the path hierarchy where no resources are currently mapped. For example,
lets continue with the last example but this time include the interceptor:

  require 'rubygems'
  require 'dav4rack'
  
  use Rack::CommonLogger
  app = Rack::Builder.new{
    map '/webdav/share/' do
      run DAV4Rack::Handler.new(:root => '/path/to/public/fileshare', :root_uri_path => '/webdav/share/')
    end
    map '/webdav/share2/' do
      run DAV4Rack::Handler.new(:resource_class => CustomResource, :root_uri_path => '/webdav/share2/')
    end
    map '/' do
      use DAV4Rack::Interceptor, :mappings => {
                                                '/webdav/share/' => {:resource_class => FileResource, :options => {:custom => 'option'}},
                                                '/webdav/share2/' => {:resource_class => CustomResource}
                                              }
      use Rails::Rack::Static
      run ActionController::Dispatcher.new
    end
  }.to_app
  run app

In this example we have two WebDAV resources restricted by path. This means those resources will handle requests to /webdav/share/*
and /webdav/share2/* but nothing above that. To allow webdav to respond, we provide the Interceptor. The Interceptor does not
provide any authentication support. It simply creates a virtual file system view to the provided mapped paths. Once the actual
resources have been reached, authentication will be enforced based on the requirements defined by the individual resource. Also
note in the root map you can see we are running a Rails application. This is how you can easily enable DAV4Rack with your Rails
application.

## Custom Resources

Creating your own resource is easy. Simply inherit the DAV4Rack::Resource class, and start redefining all the methods
you want to customize. The DAV4Rack::Resource class only has implementations for methods that can be provided extremely
generically. This means that most things will require at least some sort of implementation. However, because the Resource
is defined so generically, and the Controller simply passes the request on to the Resource, it is easy to create fully
virtualized resources.

## Helpers

There are some helpers worth mentioning that make things a little easier. DAV4Rack::Resource#accept_redirect? method is available to Resources.
If true, the currently connected client will accept and properly use a 302 redirect for a GET request. Most clients do not properly
support this, which can be a real pain when working with virtualized files that may located some where else, like S3. To deal with
those clients that don't support redirects, a helper has been provided so resources don't have to deal with proxying themselves. The 
DAV4Rack::RemoteFile allows the resource to simple tell Rack to download and send the file from the provided resource and go away, allowing the 
process to be freed up to deal with other waiters. A very simple example:

  class MyResource < DAV4Rack::Resource
    def initialize(*args)
      super(*args)
      @item = method_to_fill_this_properly
    end
    
    def get
      if(accept_redirect?)
        response.redirect item[:url]
      else
        response.body = DAV4Rack::RemoteFile.new(item[:url], :size => content_length, :mime_type => content_type)
        OK
      end
    end
  end
  
## Issues/Bugs/Questions

Please use the issues at github: http://github.com/chrisroberts/dav4rack

## Footnotes:

[1]: http://github.com/georgi/rack_dav
