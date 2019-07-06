require "droplet_kit"
require "fileutils"
require "yaml"
require 'rest-client'
require 'json'

$input_array = ARGV

class Scaler
    def initialize
        config = YAML::load(File.open("config/config.yml"))
        @client = DropletKit::Client.new(access_token: config["DO_API_Key"])

        @cpu_threshold_max = config["CPU_Threshold_Max"]
        @cpu_threshold_min = config["CPU_Threshold_Min"]
        @image = config["Image"]
        @keys = config["Keys"]
        @max_droplets = config["Max_Droplets"]
        @min_droplets = config["Min_Droplets"]
        @netdata_port = config["Netdata_Port"]
        @prefix = config["Prefix"]
        @private_networking = config["Private_Networking"]
        @region = config["Region"]
        @size = config["Droplet_Size"]
        @tag = config["Autoscale_Tag"]
        @all_tags = config["Additional_Tags"].unshift(@tag)

        @verbose = $input_array.include? "--verbose"

        @droplets = []
        @droplet_count = 0
        
        @cpu_averages = []
        @cpu_overall_average = 0
    end

    def get_droplets
        @droplets = @client.droplets.all(tag_name: @tag)
        @droplets.each do |droplet|
            if @verbose
                print droplet.id.to_s + "\t"
                print droplet.name.to_s + "\t"
                print droplet.networks.v4[0].ip_address.to_s + "\t"
                print droplet.status.to_s + "\t"
                print droplet.region.slug.to_s + "\t"
                print droplet.created_at.to_s + "\t"
                
                tag_count = 0
                if !droplet.tags.empty?
                    droplet.tags.each do |tag|
                        if tag_count != 0 then
                            print ","
                        end
                        print tag.to_s
                        tag_count += 1
                    end
                end
                
                print "\n"
            end
            @droplet_count += 1
        end
        puts "Current #{@tag} droplets active: #{@droplet_count}"
    end

    def get_cpu
        get_droplets

        count = 0
        @droplets.each do |droplet|
            print droplet.name.to_s + "\t" if @verbose

            address = "http://" + droplet.networks.v4[0].ip_address.to_s + ":" + @netdata_port.to_s + \
                "/api/v1/data?chart=system.cpu&after=-60&points=1&group=average&format=json&options=seconds,jsonwrap"
            cpu_data_raw = RestClient.get(address)            
            #puts cpu_data_raw

            cpu_data_parsed = JSON.parse(cpu_data_raw)
            #puts cpu_data_parsed
            
            cpu_usage = 0;
            if !cpu_data_parsed["result"]["data"].empty?
                cpu_data_parsed["result"]["data"][0].each do |usage|
                    next if usage > 100
                    cpu_usage += usage
                end
            end
            puts cpu_usage.round(2).to_s + "%" if @verbose
            @cpu_averages[count] = cpu_usage
            count += 1
        end
        @cpu_overall_average = @cpu_averages.inject(0){|sum,x| sum + x } / @droplet_count
        puts "Overall average: #{@cpu_overall_average.round(2)}%"
    end

    def scale
        get_cpu

        if @cpu_overall_average > @cpu_threshold_max && @droplet_count < @max_droplets || @droplet_count < @min_droplets
            scale_up
        elsif @cpu_overall_average < @cpu_threshold_min && @droplet_count > @min_droplets || @droplet_count > @max_droplets
            scale_down
        else
            puts "All looks good!"
        end
    end

    def scale_up
        puts "Scaling Up"

        droplet = DropletKit::Droplet.new(
            name: "#{@prefix}-#{SecureRandom.hex(3)}",
            region: @region,
            size: @size,
            image: @image,
            ssh_keys: @keys,
            tags: @all_tags,
            private_networking: @private_networking
        )

        droplet_create = @client.droplets.create(droplet)
        puts "Scaled up - added droplet #{droplet_create.name.to_s}"
    end

    def scale_down
        puts "Scaling Down"

        to_remove = 0
        to_remove_name = ""
        date_to_remove = Time.parse('01-01-1970')
        @droplets.each do |droplet|
            created_at = Time.parse(droplet.created_at)
            if created_at > date_to_remove
                to_remove = droplet.id
                to_remove_name = droplet.name.to_s
                date_to_remove = created_at
            end
        end

        puts "Removing droplet #{to_remove_name}"
        @client.droplets.delete(id: to_remove)
    end

    def get_ssh_keys
        keys = @client.ssh_keys.all
        keys.each do |key|
            print key.id.to_s + "\t"
            print key.name.to_s + "\n"
        end
    end

    def get_images
        images = @client.images.all
        images.each do |image|
            print image.id.to_s + "\t"
            print image.name.to_s + "\t"
            print image.type.to_s + "\t"
            print image.size_gigabytes.to_s + "\t"
            print image.distribution.to_s + "\n"
        end
    end

    def get_snapshots
        snapshots = @client.snapshots.all
        snapshots.each do |snap|
            print snap.id.to_s + "\t"
            print snap.name.to_s + "\t"
            print snap.size_gigabytes.to_s + "\t"
            print snap.min_disk_size.to_s + "\t"
            print snap.resource_type.to_s + "\n"
        end
    end

    def get_regions
        regions = @client.regions.all
        regions.each do |region|
            print region.slug.to_s + "\t"
            print region.name.to_s + "\t"
            print region.available.to_s + "\n"
        end
    end

    def get_sizes
        sizes = @client.sizes.all
        sizes.each do |size|
            print size.slug.to_s + "\t"
            print size.vcpus.to_s + "vcpus\t"
            print size.memory.to_s + "MB RAM\t"
            print size.disk.to_s + "GB disk\t"
            print size.price_monthly.to_s + "$/mo\n"
        end
    end
end

do_scaler = Scaler.new

case $input_array[0]
when "scale"
    do_scaler.scale
    when "list"
        case $input_array[1]
        when "keys"
            do_scaler.get_ssh_keys
        when "images"
            do_scaler.get_images
        when "snapshots"
            do_scaler.get_snapshots
        when "regions"
            do_scaler.get_regions
        when "sizes"
            do_scaler.get_sizes
        when "help"
            puts "Available options: keys, images, snapshots, regions, sizes, help"
        else
            puts "Available options: keys, images, snapshots, regions, sizes, help"
        end
when "help"
    puts "Available commands: scale, list [keys, images, snapshots, regions, sizes], help"
else
    puts "Available commands: scale, list [keys, images, snapshots, regions, sizes], help"
end