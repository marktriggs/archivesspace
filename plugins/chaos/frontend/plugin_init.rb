require 'rubygems'
require 'tmpdir'
require 'tempfile'
require 'json'
require 'ashttp'
require 'net/http'
require 'securerandom'

$url = "http://localhost:4567"

class CreateChaoticRecords

  def url(uri)
    URI("#{$url}#{uri}")
  end


  def do_post(s, url, content_type = 'application/x-www-form-urlencoded', high_priority = false)
    ASHTTP.start_uri(url) do |http|
      req = Net::HTTP::Post.new(url.request_uri)
      req.body = s
      req['Content-Type'] = content_type
      req["X-ARCHIVESSPACE-SESSION"] = @session if @session
      req['X-ARCHIVESSPACE-PRIORITY'] = high_priority ? "high" : "low"

      r = http.request(req)
      {:body => JSON(r.body), :status => r.code}
    end
  end


  def do_get(url, raw = false)
    ASHTTP.start_uri(url) do |http|
      req = Net::HTTP::Get.new(url.request_uri)
      req["X-ARCHIVESSPACE-SESSION"] = @session if @session
      r = http.request(req)

      if raw
        r
      else
        {:body => JSON(r.body), :status => r.code}
      end
    end
  end


  def do_delete(url)
    ASHTTP.start_uri(url) do |http|
      req = Net::HTTP::Delete.new(url.request_uri)
      req["X-ARCHIVESSPACE-SESSION"] = @session if @session
      http.request(req)
    end
  end


  def main

    puts "Create an admin session"
    r = do_post(URI.encode_www_form(:password => "admin"),
                url("/users/admin/login?expiring=false"))

    @session = r[:body]["session"] or raise "Admin login #{r}"

    repo_id = 2

    puts "Create a resource"
    r = do_post({
                  :title => "integration test resource #{$$}",
                  :id_0 => SecureRandom.hex,
                  :dates => [ { "date_type" => "single", "label" => "creation", "expression" => "1492" } ],
                  :finding_aid_language => "eng",
                  :finding_aid_script => "Latn",
                  :lang_materials => [{"language_and_script" => {"language" => "eng"}}],
                  :level => "collection",
                  :extents => [{"portion" => "whole", "number" => "5 or so", "extent_type" => "reels"}]
                }.to_json,
                url("/repositories/#{repo_id}/resources"),
                'text/json')

    coll_id = r[:body]["id"] or raise "Resource creation: #{r}"


    success_count = java.util.concurrent.atomic.AtomicLong.new(0)
    failure_count = java.util.concurrent.atomic.AtomicLong.new(0)

    threads = []
    (0...12).each do |thread_id|
      threads << Thread.new do
        30.times do
          puts "Create an archival object under a resource"
          r = do_post({
                        :title => "integration test archival object #{$$} - under a resource",
                        :resource => {'ref' => "/repositories/#{repo_id}/resources/#{coll_id}"},
                        :level => "item"
                      }.to_json,
                      url("/repositories/#{repo_id}/archival_objects"),
                      'text/json')

          if r[:body]["id"]
            success_count.increment_and_get
          else
            failure_count.increment_and_get
          end
        end
      end
    end

    threads.each(&:join)

    puts "\n\nSuccess: #{success_count.get}; Failures: #{failure_count.get}"
  end
end

CreateChaoticRecords.new.main
