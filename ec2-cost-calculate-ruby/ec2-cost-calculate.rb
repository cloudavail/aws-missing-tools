#!/usr/bin/ruby
access_key = ""
secret_key = ""
#default options are given below - user input can override any one of these
options = {:fileoutputlocation => "~/ec-cost-calculate-result.txt", :output => "screen",:seperator => ",",:region => "all",:period => "hour",:multiplier => 1,:status => :running, :awscredentialsfile => "", :awscredentialssource => "env", :user_selected_region => "all", :mode => "byinstance" }
#ec2cc_resources holds resources needed by ec2_cost_calculate, such as the output file handle
ec2cc_resources = {}
#mysql_connection_info holds resources needed if a mysql connection is going to be utilized
mysql_connection_info = {:mysqlport => 3306 }
#list of valid statuses for an instance - will be used to validate user input
instance_valid_statuses = [:pending, :running, :shutting_down, :terminated, :stopping, :stopped]

require 'optparse'
require 'net/http'
require 'rubygems'
require 'aws-sdk'
require 'mysql'

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
    when "mysql"
      ec2cc_object_insert = ec2cc_resources[:mysql_connection_object].prepare("insert into costs (id,region,platform,instance_type,status,cost,name,autoscalinggroup,date) values (?,?,?,?,?,?,?,?,?)")
      ec2cc_object_insert.execute("#{ec2_object.id}","#{ec2_object.region}","#{ec2_object.platform}","#{ec2_object.instance_type}","#{ec2_object.status}","#{ec2_object.price}","#{ec2_object.name}","#{ec2_object.asg}",Time.now)
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

#CostASG is used when mode is "byasg"- one CostASG object exists per Auto Scaling Group
class CostASG
  attr_accessor :name, :region, :instance_type,:total_instance_count, :total_cost
  def initialize(name,region,instance_type,total_instance_count,total_cost)
    @name = name
    @region = region
    @instance_type = instance_type
    @total_instance_count = total_instance_count
    @total_cost = total_cost
  end
  def output (options,asg_cost_object,ec2cc_resources)
    outputstring = "#{asg_cost_object.name}","#{options[:seperator]}","#{asg_cost_object.region}","#{options[:seperator]}","#{asg_cost_object.instance_type}","#{options[:seperator]}","#{asg_cost_object.total_instance_count}","#{options[:seperator]}","#{asg_cost_object.total_cost}","\n"
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
  opts.on("-o","--output OUTPUT","Output method. Accepts values \"screen\", \"file\" or \"mysql.\" Default value is \"screen\".") do |output|
    #forces option to lowercase - easier to evaluate variables when always lowercase
    output.downcase!
    if (output == "screen" || output == "file" || output == "mysql" )
      options[:output] = output
    else
      $stderr.print "You must specifiy an output method such as \"screen\", \"file\" or \"mysql.\" You specified \"", output, ".\"\n"
      exit 64
    end
  end
  #mode - allowing either "byinstance" - in which the cost of each instance is listed or "byASG" in which the cost of each ASG is listed
  opts.on("-m","--mode MODE","mode in which ", program_name, " runs. Accepts values \"byinstance\" or \"byASG.\" Default value is \"byinstance\".") do |mode|
    #forces option to lowercase - easier to evaluate variables when always lowercase
    mode.downcase!
    if (mode == "byinstance" || mode == "byasg")
      options[:mode] = mode
    else
      $stderr.print "You must specifiy a mode such as \"byinstance\" or \"byasg\". You specified \"", mode, ".\"\n"
      exit 64
    end
  end
  #options processing for aws credential file input
  opts.on("--awscredentialfile CREDENTIAILFILE","path to AWS credential file. This is required if the path to an AWS credential file is not provided by an environment variable.") do |awscredentialfile|
    options[:awscredentialfile] = awscredentialfile
    options[:awscredentialssource] = "file"
  end
  #MySQL Configuration
  opts.on("--mysqluser MYSQLUSER","username to be used when connecting to MySQL database") do |mysql_user|
    mysql_connection_info[:mysql_user] = mysql_user
  end
  opts.on("--mysqlpass MYSQLPASS","password to be used when connecting to MySQL database") do |mysql_pass|
    mysql_connection_info[:mysql_pass] = mysql_pass
  end
  opts.on("--mysqlhost MYSQLHOST","host to be used when connecting to MySQL database") do |mysql_host|
    mysql_connection_info[:mysql_host] = mysql_host
  end
  opts.on("--mysqlport MYSQLPORT","port to be used when connecting to MySQL database") do |mysql_port|
    mysql_connection_info[:mysql_port] = mysql_port.to_i
  end
end
optparse.parse!

#ensures that if output is mysql that mysqluser, mysqlpass and mysqlhost are set
if options[:output] == "mysql"
  if mysql_connection_info[:mysql_user].nil?
    $stderr.print "If you are outputing to MySQL using \"--output mysql\" you must specify a mysql username using \"--mysqluser.\"\n"
    exit 64;
  end
  if mysql_connection_info[:mysql_pass].nil?
    $stderr.print "If you are outputing to MySQL using \"--output mysql\" you must specify a mysql password using \"--mysqlpass.\"\n"
    exit 64;
  end
  if mysql_connection_info[:mysql_host].nil?
    $stderr.print "If you are outputing to MySQL using \"--output mysql\" you must specify a mysql hostname using \"--mysqlhost.\"\n"
    exit 64;
  end
end

#case statement determines the location where AWS credentials should be gotten. Defaults to "env" (environment) if set to "file" will read from a user provided file.
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
price_table = Net::HTTP.get('s3.amazonaws.com', '/colinjohnson-cloudavailprd/aws-ec2-cost-map.txt')
#establishes an initial connection object to AWS
aws_interface = AWS::EC2.new( :access_key_id => access_key, :secret_access_key => secret_key)

#creates a collection (currently, an array) of all ec2 objects
instance_collection = {};
#creates a collection (currently, an array) of all regions resources
region_collection = {};
#creates a collection (currently, an array) of all asg costs objects
asg_cost_collection = {};
#regions_aws is a list of all current Amazon regions
regions_array = aws_interface.regions.map
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

if options[:output] == "mysql"
  ec2cc_resources[:mysql_connection_object] = Mysql.real_connect(mysql_connection_info[:mysql_host],mysql_connection_info[:mysql_user],mysql_connection_info[:mysql_pass],"ec2cc",mysql_connection_info[:mysql_port])
end


#region selection done outside of optparse
if options[:user_selected_region] == "all"
  $stderr.print "Region \"all\" has been selected.\n"
else
  if regions_array.detect {|region_evaluated| region_evaluated.name == options[:user_selected_region] }
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
  regions_array.each do |region|
      region_interface = AWS::EC2.new( :access_key_id => access_key, :secret_access_key => secret_key, :ec2_endpoint => region.endpoint) 
      region_object = Region_Resource.new(region.name,region.endpoint,region_interface)
      region_collection[region.to_s] = region_object
    end
else
  regions_array.each do |region|
    if options[:region] == region.name
      region_interface = AWS::EC2.new( :access_key_id => access_key, :secret_access_key => secret_key, :ec2_endpoint => region.endpoint) 
      region_object = Region_Resource.new(region.name,region.endpoint,region_interface)
      region_collection[region.to_s] = region_object
    end
  end
end

#AWS.memoize "causes the sdk to hold onto information until the end of the memoization block" - rather than return information for each function. Performance improvement went from slow (~1 second per instance to 5 seconds for 200 instances)
AWS.memoize do
  #First Code Block: passes in regional_resource (endpoint) - 1 call for each AWS region
  #Second Code Block: for each region, list all EC2 instances
  region_collection.each do |region_name, region_object|
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
      
      #if mode is "byasg" create a new asg cost object and then insert into the asg_cost_collection
      if options[:mode] == "byasg"
        #handles case where "ASG" tag is not set, sets to "<nil> string"
        if ec2_object.asg.nil?
          ec2_object.asg = "<nil>"
        end
        #asg_unique_id is a unique id for each Auto Scaling Group in each region. Converting all values to strings (to_s) ensures no errors when concatinating - one example of a need to convert to string is a "nil" value for ASG - which would cause errors on concatenation.
        asg_unique_id = ec2_object.asg.to_s + "," + ec2_object.region.to_s + "," + ec2_object.instance_type.to_s
        #if asg_unique_id exists already, add to instance count and total cost
        if asg_cost_collection.include?(asg_unique_id)
          asg_cost_collection[asg_unique_id].total_instance_count += 1
          asg_cost_collection[asg_unique_id].total_cost += ec2_object.price
        #else create a new asg_cost_object and place in asg_cost_collection
        else
          asg_cost_object = CostASG.new(ec2_object.asg,ec2_object.region,ec2_object.instance_type,1,ec2_object.price)
          asg_cost_collection[asg_unique_id] = asg_cost_object
        end
      end
      #places each ec2_object into the instance_collection if the status of instance matches user requested status
      if options[:status] == instance.status
        instance_collection[instance.id] = ec2_object
      end
    end
  end
end

#Prints Header
case options[:mode]
  when "byinstance"
    headerstring = "instanceid","#{options[:seperator]}","region","#{options[:seperator]}","platform","#{options[:seperator]}","status","#{options[:seperator]}","cost","#{options[:seperator]}","name","#{options[:seperator]}","autoscalinggroup","\n"
  when "byasg"
    headerstring = "asgname","#{options[:seperator]}","region","#{options[:seperator]}","instanceplatform","#{options[:seperator]}","instancecount","#{options[:seperator]}","asgcost","\n"
end

case options[:output]
  when "screen"
    print headerstring
  when "file"
    ec2cc_resources[:ec2_output_file_handle].print headerstring
end

case options[:mode]
  when "byinstance"
    instance_collection.each do |ec2_instance_id,ec2_instance_object|
      ec2_instance_object.output(options,ec2_instance_object,ec2cc_resources)
    end
  when "byasg"
    asg_cost_collection.each do |asg_unique_id,asg_cost_object|
      asg_cost_object.output(options,asg_cost_object,ec2cc_resources)
    end
end
