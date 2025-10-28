#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'digest'
require 'base64'
require 'logger'

# This class represents a local file to be uploaded to S3.
class LocalFile
  attr_reader :path

  def initialize(path)
    @path = path
    @logger = Logger.new($stdout)
  end

  def calculate_sha256
    checksum = Digest::SHA256.new
    File.open(@path, 'rb') do |file|
      buffer = ''
      checksum.update(buffer) while file.read(1024, buffer)
    end
    checksum.hexdigest
  end

  def upload(bucket_name, object_key, options = {})
    tm = Aws::S3::TransferManager.new
    begin
      tm.upload_file(@path, bucket: bucket_name, key: object_key, **options)
      @logger.info("File #{@path} successfully uploaded to #{bucket_name}:#{object_key}.")
      true
    rescue StandardError => e
      @logger.error("Upload failed: #{e.message}")
      false
    end
  end
end

# This class represents an S3 object and provides methods to retrieve its checksum.
class S3Object
  attr_reader :bucket_name, :object_key

  def initialize(bucket_name, object_key)
    @bucket_name = bucket_name
    @object_key = object_key
    @logger = Logger.new($stdout)
  end

  def sha256
    s3_client = Aws::S3::Client.new
    resp = s3_client.get_object_attributes(bucket: @bucket_name, key: @object_key, object_attributes: ['Checksum'])
    decode_checksum(resp.checksum.checksum_sha256)
  end

  private

  def decode_checksum(encoded_checksum)
    Base64.decode64(encoded_checksum).unpack1('H*')
  end
end

def run_test # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  logger = Logger.new($stdout)

  bucket_name = ARGV[0]
  object_key = ARGV[1]
  file_path = ARGV[2]
  options = {
    checksum_algorithm: 'SHA256'
  }

  local_file = LocalFile.new(file_path)
  start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  return unless local_file.upload(bucket_name, object_key, options)

  end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  duration = end_time - start_time

  logger.debug("Upload completed in #{duration.round(2)} seconds.")

  logger.info('Comparing checksums...')
  local_checksum = local_file.calculate_sha256
  s3_checksum = S3Object.new(bucket_name, object_key).sha256

  if local_checksum == s3_checksum
    logger.info('Checksums match!')
    logger.debug("Checksum: #{local_checksum}")
  else
    logger.warning('Checksums do not match!')
    logger.debug("Local: #{local_checksum}")
    logger.debug("S3:    #{s3_checksum}")
  end
end

run_test if $PROGRAM_NAME == __FILE__
