#!/usr/bin/env ruby

require "aws-sdk-s3"
require "digest"
require "base64"

class Local_File
  attr_reader :path

  def initialize(path)
    @path = path
  end

  def calculate_sha256()
    checksum = Digest::SHA256.new
    File.open(@path, "rb") do |file|
      buffer = ""
      while file.read(1024, buffer)
        checksum.update(buffer)
      end
    end
    checksum.hexdigest
  end

  def upload(bucket_name, object_key, options = {})
    tm = Aws::S3::TransferManager.new
    begin
      tm.upload_file(@path, bucket: bucket_name, key: object_key, **options)
      puts "File #{@path} successfully uploaded to #{bucket_name}:#{object_key}."
      true
    rescue StandardError => e
      puts "Upload failed: #{e.message}"
      false
    end
  end
end

class S3_Object
  attr_reader :bucket_name, :object_key

  def initialize(bucket_name, object_key)
    @bucket_name = bucket_name
    @object_key = object_key
  end

  def get_s3_object_sha256()
    s3_client = get_s3_client()
    resp = s3_client.get_object_attributes(bucket: @bucket_name, key: @object_key, object_attributes: ["Checksum"])
    decode_checksum(resp.checksum.checksum_sha256)
  end

  private
  def decode_checksum(encoded_checksum)
    Base64.decode64(encoded_checksum).unpack1("H*")
  end

  def get_s3_client()
    Aws::S3::Client.new
  end
end

def run_test
  bucket_name = ARGV[0]
  object_key = ARGV[1]
  file_path = ARGV[2]
  options = {
    checksum_algorithm: "SHA256"
  }

  local_file = Local_File.new(file_path)
  start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  return unless local_file.upload(bucket_name, object_key, options)
  end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  duration = end_time - start_time

  puts "Upload completed in #{duration.round(2)} seconds."
  
  puts "Comparing checksums..."
  local_checksum = local_file.calculate_sha256()
  s3_checksum = S3_Object.new(bucket_name, object_key).get_s3_object_sha256()

  if local_checksum == s3_checksum
    puts "Checksums match!"
    puts "Checksum: #{local_checksum}"
  else
    puts "Checksums do not match!"
    puts "Local: #{local_checksum}"
    puts "S3:    #{s3_checksum}"
  end
end

run_test if $PROGRAM_NAME == __FILE__
