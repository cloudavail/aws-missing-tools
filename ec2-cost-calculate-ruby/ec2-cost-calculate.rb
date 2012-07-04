#!/usr/bin/ruby
access_key = ""
secret_key = ""
#default options are given below - user input can override any one of these
options = {:fileoutputlocation => "~/ec-cost-calculate-result.txt", :output => "screen",:seperator => ",",:region => "all",:period => "hour",:multiplier => 1,:status => :running, :awscredentialsfile => "", :awscredentialssource => "env", :user_selected_region => "all" }
#ec2cc_resources holds resources needed by ec2_cost_calculate, such as the output file handle
ec2cc_resources = {}
#list of valid statuses for an instance - will be used to validate user input
instance_valid_statuses = [:pending, :running, :shutting_down, :terminated, :stopping, :stopped]

require 'optparse'
require 'net/http'
require 'rubygems'
require 'aws-sdk'

class Instance
#attr_accesors create variable setters and getters
  attr_accessor :id, :availability_zone, :region, :instance_type, :platform, :status
  attr_accessor :name
  attr_accessor :asg
  attr_accessor :price

#the variables set by "initialize" are those required for Instance instantiatiot
  def initialize(id,region,availability_zone,instance_type,platform,status)
    @id = id ; @region = region
    @availability_zone = availability_zone
    @instance_type = instance_type
    @platform = platform
    @status = status
  end
  
  def get_price(instance_type,region,os,price_table,multiplier)
    price = price_table.match(/#{region},#{instance_type},#{os},.*/).to_s.split(",")
    @price = price[3].to_f * multiplier.to_f
  end

  def output(options,ec2_object,ec2cc_resources)
    #outputstring below allows the initialization of how data should be outpout - it is used for both file and screen output. As for the use of a number of strings - I found the formatting easier to read but I'd be open to using one string if evidence supported that being a better way to do this
    outputstring = "#{ec2_object.id}","#{options[:seperator]}","#{ec2_object.region}","#{options[:seperator]}","#{ec2_object.platform}","#{options[:seperator]}","#{ec2_object.status}","#{options[:seperator]}","#{ec2_object.price}","#{options[:seperator]}","#{ec2_object.name}","#{options[:seperator]}","#{ec2_object.asg}","\n"
    case options[:output]
    when "file"
      ec2cc_resources[:ec2_output_file_handle].print outputstring
    when "screen"
      print outputstring
    else 
      $stderr.print "error with output.\n"
      exit 1
    end    
  end
end

class Region_Resource
  attr_accessor :region_name, :region_endpoint, :region_interface
  def initialize(region_name,region_endpoint,region_interface)
    @region_name = region_name
    @region_endpoint = region_endpoint
    @region_interface = region_interface
  end
end

## ec2-cost-calculate ##
## Initialization of ec2-cost-calculate
#sets program name
program_name = File.basename($PROGRAM_NAME)

#begin Options Parsing
optparse = OptionParser.new do |opts|
  #sets options banner
  opts.banner = "Usage: #{program_name} [options]"
  #options processing: output
  opts.on("-o","--output OUTPUT","Output method. Accepts values \"screen\" or \"file.\" Default value is \"screen\".") do |output|
    #forces option to lowercase - easier to evaluate variables when always lowercase
    output.downcase!
    if (output == "screen" || output == "file")
      options[:output] = output
    else
      $stderr.print "You must specifiy an output method such as \"screen\" or \"file\". You specified \"", output, ".\"\n"
      exit 64
    end
  end
  #options process: filename is "file" is selected as output
  opts.on("-f","--file FILE","File output location. Only used when the output location \"File\" is selected.") do |file|
    #forces option to lowercase - easier to evaluate variables when always lowercase
    file.downcase!
    #the "file" option is only useful if the output is to a file
    options[:fileoutputlocation] = file
  end
  #options processing: used to create seperator
  opts.on('-s','--seperator SEPERATOR',"Character to be used for seperating fields. Default value is a comma.") do |seperator|
    if options[:output] != "file" && options[:output] != "screen"
      $stderr.print "You specified a seperator with format that was not \"screen\" or \"file\". You do not need to specify a seperator for the given format.\n"
      exit 64
    end
    options[:seperator] = seperator
  end
  #options processing for region
  opts.on('-r','--region REGION',"Region for which Instance Costs Should be Provided. Accepts values such as \"us-east-1\" or \"us-west-1.\" Default value is \"all\".") do |region_selected|
    region_selected.downcase!
    options[:user_selected_region] = region_selected
  end
    #options processing for period
  opts.on('-p','--period PERIOD',"Period for Which Costs Should Be Calculated. Accepts values \"hour\", \"day\", \"week\", \"month\" or \"year\". Default value is \"hour\".") do |period|
    period.downcase!
    case period
    when "hour"
      options[:multiplier] = 1
    when "day"
      options[:multiplier] = 24
    when "week"
      options[:multiplier] = 168
    when "month"
      options[:multiplier] = 720
    when "year"
      options[:multiplier] = 8760
    else
      $stderr.print "You specified the period \"",period,".\" Valid inputs are \"hour\", \"day\", \"week\", \"month\" or \"year.\"\n"
      exit 64
    end
  end
  #options processing for status
  opts.on('-s','--status STATUS',"Status for which instance cost should be gotten. Default is \"running\" status. Acceptable inputs are \"pending\" \"running\" \"shutting_down\", \"terminated\", \"stopping\", \"stopped.\"") do |status_selected|
    status_selected.downcase!
    #if instance_valid_statuses includes the user provided status, place in the options hash
    if instance_valid_statuses.include?(status_selected.to_sym)
      options[:status] = status_selected.to_sym
    #else - the status requested didn't exist in the hash, so exit and return error code.
    else
      $stderr.print "You specified the status \"",status_selected,".\" You need to specify a valid status such as \"running\" or \"pending.\"\n"
    exit 64
    end
  end
  #options processing for aws credential file input
  opts.on("-o","--output OUTPUT","Output method. Accepts values \"screen\" or \"file.\" Default value is \"screen\".") do |output|
    #forces option to lowercase - easier to evaluate variables when always lowercase
    output.downcase!
    if (output == "screen" || output == "file")
      options[:output] = output
    else
      $stderr.print "You must specifiy an output method such as \"screen\" or \"file\". You specified \"", output, ".\"\n"
      exit 64
    end
  end
  #options processing for aws credential file input
  opts.on("--awscredentialfile CREDENTIAILFILE","path to AWS credential file. This is required if the path to an AWS credential file is not provided by an environment variable.") do |awscredentialfile|
    options[:awscredentialfile] = awscredentialfile
    options[:awscredentialssource] = "file"
  end
end
optparse.parse!

#case statement deterimnes the location where AWS credentials should be gotten. Defaults to "env" (environment) if set to "file" will read from a user provided file.
case options[:awscredentialssource]
when "env"
  credentialfile = ENV["AWS_CREDENTIAL_FILE"]
  awscredentialsmissingtext = "The environment variable AWS_CREDENTIAL_FILE must exist and point to a valid credential file in order for ", "#{program_name}", " to run. The AWS_CREDENTIAL_FILE must contain also contain the two lines below:\n AWSAccessKeyId=<your access key>\n AWSSecretKey=<your secret key>\nPlease correct this error and run again.\n"
when "file"
  credentialfile = options[:awscredentialfile]
  awscredentialsmissingtext = "The AWS Credential File you specified must exist for ", "#{program_name}", " to run. The specified file must contain also contain the two lines below:\n AWSAccessKeyId=<your access key>\n AWSSecretKey=<your secret key>\nPlease correct this error and run again.\n"
else
  $stderr.print "A problem was encountered when attempting to set AWS Credentials."
  exit 64;
end

if credentialfile.nil? || File.exists?(credentialfile) == false
  $stderr.print awscredentialsmissingtext
  exit 64;
end

File.open(credentialfile,"r").each do |line|
  #below: sets access_key equal to line read in from "AWS_CREDENTIAL_FILE" that starts with "AWSAccessKeyId=" and removes trailing character
  if line.start_with?("AWSAccessKeyId=")
    access_key = line.split("=")[1].chomp!
  end
  #below: sets secret_key equal to line read in from "AWS_CREDENTIAL_FILE" that starts with "AWSSecretKeyId=" and removes trailing character
  if line.start_with?("AWSSecretKey=")
    secret_key = line.split("=")[1].chomp!
  end
end

#gets and creates the price_table
price_table = Net::HTTP.get('s3.amazonaws.com', '/colinjohnson-cloudavaildev/aws-ec2-cost-map.txt')
#establishes an initial connection object to AWS
ec2_interface = AWS::EC2.new( :access_key_id => access_key, :secret_access_key => secret_key)

#creates a container (currently, an array) for all ec2 objects
ec2_container = {};
#creates a container (currently, an array) for all regions resources
region_container = {};
#regions_aws is a list of all current Amazon regions
regions_aws_all = ec2_interface.regions.map

#file expansion and validation done outside of optparse
#below performs expansion - ruby's File class does not support file expansion (for instance, ~/ec-cost-calculate-result.txt)
if options[:output] == "file"
  ec2cc_output_file_location = File.expand_path(options[:fileoutputlocation])
  #if File exists, exit
  if File.exists?(ec2cc_output_file_location)
    $stderr.print "The file \"", ec2cc_output_file_location, "\" already exists. Rather than overwrite this file ", program_name, " will now exit.\n"
    exit 64
  else
    options[:fileoutputlocation] = ec2cc_output_file_location
  end
  ec2cc_resources[:ec2_output_file_handle] = File.open(ec2cc_output_file_location,'a')
end

#region selection done outside of optparse
if options[:user_selected_region] == "all"
  $stderr.print "Region \"all\" has been selected.\n"
else
  if regions_aws_all.detect {|region_evaluated| region_evaluated.name == options[:user_selected_region] }
    $stderr.print "The region \"", options[:user_selected_region], "\" has been selected.\n"
    options[:region] = options[:user_selected_region]
  else
    $stderr.print "You specified the region \"",options[:user_selected_region],".\" You need to specify a valid region (example: \"us-east-1\") or region \"all\" for all regions.\n"
    exit 64
  end
end

##handle region selection - this should be improved to iterate through a list of regions
if options[:region] == "all"
  #set regions_aws_select to all
  regions_aws_all.each do |region|
      region_interface = AWS::EC2.new( :access_key_id => access_key, :secret_access_key => secret_key, :ec2_endpoint => region.endpoint) 
      region_object = Region_Resource.new(region.name,region.endpoint,region_interface)
      region_container[region.to_s] = region_object
    end
else
  regions_aws_all.each do |region|
    if options[:region] == region.name
      region_interface = AWS::EC2.new( :access_key_id => access_key, :secret_access_key => secret_key, :ec2_endpoint => region.endpoint) 
      region_object = Region_Resource.new(region.name,region.endpoint,region_interface)
      region_container[region.to_s] = region_object
    end
  end
end

#AWS.memoize "causes the sdk to hold onto information until the end of the memoization block" - rather than return information for each function. Performance improvement went from slow (~1 second per instance to 5 seconds for 200 instances)
AWS.memoize do
  #First Code Block: passes in regional_resource (endpoint) - 1 call for each AWS region
  #Second Code Block: for each region, list all EC2 instances
  region_container.each do |region_name, region_object|
    #print "Getting Information from: ",region_object.region_name," using endpoint: ",region_object.region_interface.to_s,"\n"
    #for each region_interface, get all instances and perform actions below:
    region_object.region_interface.instances.each do |instance|
      #corrects an issue where instance.platform returns nil if a "linux" based instance - see https://forums.aws.amazon.com/thread.jspa?threadID=94567&tstart=0
      if instance.platform == nil
        platform = "linux"
      else
        platform = instance.platform
      end
      #creates an "Instance" object with a number of attributes
      ec2_object = Instance.new(instance.id,region_object.region_name,instance.availability_zone,instance.instance_type,platform,instance.status)
      ec2_object.name = instance.tags["Name"]
      ec2_object.asg = instance.tags["aws:autoscaling:groupName"]
      #gets price using Instance.price method
      ec2_object.price = ec2_object.get_price(ec2_object.instance_type,ec2_object.region,ec2_object.platform,price_table,options[:multiplier])
      #places each ec2_object into the ec2_container if the status of instance matches user requested status
      if options[:status] == instance.status
        ec2_container[instance.id] = ec2_object
      end
    end
  end
end
#Prints Header
headerstring = "instanceid","#{options[:seperator]}","region","#{options[:seperator]}","platform","#{options[:seperator]}","status","#{options[:seperator]}","cost","#{options[:seperator]}","name","#{options[:seperator]}","autoscalinggroup","\n"

case options[:output]
  when "screen"
    print headerstring
  when "file"
    ec2cc_resources[:ec2_output_file_handle].print headerstring
end

#Prints Output for each EC2 object
ec2_container.each do |ec2_instance_id,ec2_instance_object|
  ec2_instance_object.output(options,ec2_instance_object,ec2cc_resources)
end