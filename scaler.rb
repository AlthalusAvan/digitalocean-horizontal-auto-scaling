require "droplet_kit"
require "fileutils"
require "yaml"
require 'rest-client'
require 'json'

class Scaler
    def initialize
        config = YAML::load(File.open("config/config.yml"))
        @client = DropletKit::Client.new(access_token: config["DO_API_Key"])

        @cpu_threshold_max = config["CPU_Threshold_Max"]
        @cpu_threshold_min = config["CPU_Threshold_Min"]
        @max_droplets = config["Max_Droplets"]
        @min_droplets = config["Min_Droplets"]
        @netdata_port = config["Netdata_Port"]
        @tag = config["Autoscale_Tag"]

        @droplets = []
        @droplet_count = 0
        
        @cpu_averages = []
        @cpu_overall_average = 0
    end

    def get_droplets
        @droplets = @client.droplets.all(tag_name: @tag)
        @droplets.each do |droplet|
            /
            print droplet.id.to_s + "\t"
            print droplet.name.to_s + "\t"
            print droplet.networks.v4[0].ip_address.to_s + "\t"
            print droplet.status.to_s + "\t"
            print droplet.region.slug.to_s + "\t"

            tag_count = 0
            droplet.tags.each do |tag|
                if tag_count != 0 then
                    print ","
                end
                print tag.to_s
                tag_count += 1
            end

            print "\n"
            /
            @droplet_count += 1
        end
        puts "Current #{@tag} droplets active: #{@droplet_count}"
    end

    def get_cpu
        get_droplets

        count = 0
        @droplets.each do |droplet|
            print droplet.name.to_s + "\t"

            address = "http://" + droplet.networks.v4[0].ip_address.to_s + ":" + @netdata_port.to_s + \
                "/api/v1/data?chart=system.cpu&after=-60&points=1&group=average&format=json&options=seconds,jsonwrap"
            cpu_data_raw = RestClient.get(address)            
            #puts cpu_data_raw

            cpu_data_parsed = JSON.parse(cpu_data_raw)
            #puts cpu_data_parsed
            
            cpu_usage = 0;
            cpu_data_parsed["result"]["data"][0].each do |usage|
                next if usage > 100
                cpu_usage += usage
            end
            puts cpu_usage.round(2).to_s + "%"
            @cpu_averages[count] = cpu_usage
            count += 1
        end
        @cpu_overall_average = @cpu_averages.inject(0){|sum,x| sum + x } / @droplet_count
        puts "Overall average: #{@cpu_overall_average.round(2)}%"
    end

    def scale
        get_cpu

        if @cpu_overall_average > @cpu_threshold_max && @droplet_count < @max_droplets
            scale_up
        elsif @cpu_overall_average < @cpu_threshold_min && @droplet_count > @min_droplets
            scale_down
        else
            puts "All looks good!"
        end
    end

    def scale_up
        puts "Scale Up"
    end

    def scale_down
        puts "Scale Down"
    end
end

do_scaler = Scaler.new
do_scaler.scale

