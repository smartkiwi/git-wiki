#!/usr/bin/env ruby

require 'environment'
#require '/usr/lib/ruby/user-gems/1.8/gems/sinatra-0.1.7/lib/sinatra.rb'


#%w(rubygems sinatra git bluecloth rubypants haml).each do |dependency|                                         
#%w(rubygems sinatra).each do |dependency|                                         
#
#    begin                                                                                                        
#	require dependency                                                                                         
#    rescue LoadError => e                                                                                        
#	puts "You need to install #{dependency} before we can proceed"                                             
#    end                                                                                                          
#end      


layout do                                                                                              
    File.read('views/layout.erb')
end

get('/') { redirect "/#{HOMEPAGE}" }


get('/_style.css') { header 'Content-Type' => 'text/css'; File.read(File.join(File.dirname(__FILE__), 'css', 'style.css')) }                                                      
#get('/_code.css') { header 'Content-Type' => 'text/css'; File.read(File.join(File.dirname(__FILE__), 'css', "#{UV_THEME}.css")) }                                                                                             
get('/_app.js') { header 'Content-Type' => 'application/x-javascript'; File.read(File.join(File.dirname(__FILE__), 'javascripts', "application.js")) }
# page paths

get '/:page' do
  @page = Page.new(params[:page])
  @page.tracked? ? show(:show, @page.name) : redirect('/e/' + @page.name)
end

get '/:page/raw' do
  @page = Page.new(params[:page])
  @page.raw_body
end

get '/:page/append' do
  @page = Page.new(params[:page])
  @page.body = @page.raw_body + "\n\n" + params[:text]
  redirect '/' + @page.name
end

get '/e/:page' do
  @page = Page.new(params[:page])
  show :edit, "Editing #{@page.name}"
end

post '/e/:page' do
  @page = Page.new(params[:page])
  @page.update(params[:body], params[:message])
  redirect '/' + @page.name
end

post '/eip/:page' do
  @page = Page.new(params[:page])
  @page.update(params[:body])
  @page.body
end

get '/h/:page' do
  @page = Page.new(params[:page])
  show :history, "History of #{@page.name}"
end

get '/h/:page/:rev' do
  @page = Page.new(params[:page], params[:rev])
  show :show, "#{@page.name} (version #{params[:rev]})"
end

get '/d/:page/:rev' do
  @page = Page.new(params[:page])
  show :delta, "Diff of #{@page.name}"
end

# application paths (/a/ namespace)

get '/a/list' do
  @pages = $repo.log.first.gtree.children.map { |name, blob| Page.new(name) } rescue []
  show(:list, 'Listing pages')  
end

get '/a/patch/:page/:rev' do
  @page = Page.new(params[:page])
  header 'Content-Type' => 'text/x-diff'
  header 'Content-Disposition' => 'filename=patch.diff'
  @page.delta(params[:rev])
end

get '/a/tarball' do
  header 'Content-Type' => 'application/x-gzip'
  header 'Content-Disposition' => 'filename=archive.tgz'
  archive = $repo.archive('HEAD', nil, :format => 'tgz', :prefix => 'wiki/')
  File.open(archive).read
end

get '/a/branches' do
  @branches = $repo.branches
  show :branches, "Branches List"
end

get '/a/branch/:branch' do
  $repo.checkout(params[:branch])
  redirect '/' + HOMEPAGE
end

get '/a/history' do
  @history = $repo.log
  show :branch_history, "Branch History"
end

get '/a/revert_branch/:sha' do
  $repo.with_temp_index do 
    $repo.read_tree params[:sha]
    $repo.checkout_index
    $repo.commit('reverted branch')
  end
  redirect '/a/history'
end

get '/a/merge_branch/:branch' do
  $repo.merge(params[:branch])
  redirect '/' + HOMEPAGE
end

get '/a/delete_branch/:branch' do
  $repo.branch(params[:branch]).delete
  redirect '/a/branches'
end

post '/a/new_branch' do
  $repo.branch(params[:branch]).create
  $repo.checkout(params[:branch])
  if params[:type] == 'blank'
    # clear out the branch
    $repo.chdir do 
      Dir.glob("*").each do |f|
        File.unlink(f)
        $repo.remove(f)
      end
      touchfile
      $repo.commit('clean branch start')
    end
  end
  redirect '/a/branches'
end

post '/a/new_remote' do
  $repo.add_remote(params[:branch_name], params[:branch_url])
  $repo.fetch(params[:branch_name])
  redirect '/a/branches'
end

get '/a/search' do
  @search = params[:search]
  @grep = $repo.grep(@search)
  show :search, 'Search Results'
end

# support methods

def page_url(page)
  "#{request.env["rack.url_scheme"]}://#{request.env["HTTP_HOST"]}/#{page}"
end

private

  def show(template, title)
    @title = title

    erb template
  end

  def touchfile
    # adds meta file to repo so we have somthing to commit initially
    $repo.chdir do
      f = File.new(".meta",  "w+")
      f.puts($repo.current_branch)
      f.close
      $repo.add('.meta')
    end
  end