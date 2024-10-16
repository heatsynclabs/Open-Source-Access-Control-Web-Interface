class MacsController < ApplicationController
load_and_authorize_resource :mac, :except => [:index, :create, :history]
#load_and_authorize_resource :user, :through => :mac, :except => [:index, :show, :scan, :import]

before_filter :arp_lookup, :only => :new

#require "active_record"
require "optparse"
#require "rubygems"

def index
  recent_mac_logs_ungrouped = MacLog.last(1000)
  if recent_mac_logs_ungrouped.present?
    @mac_time_start_date = recent_mac_logs_ungrouped.first.created_at
    recent_mac_logs = recent_mac_logs_ungrouped.group_by(&:mac)
    @mac_times = {}
    # Go thru each mac
    recent_mac_logs.each do |mac_log|
      last_active = nil
      # And the entries for each mac (mac_log.first is the string, mac_log.last is the array)
      mac_log.last.each do |entry|
        # Find an activate followed immediately by a deactivate
        if entry.action == "activate"
          last_active = entry
        else
          if last_active && entry.action == "deactivate"
            # Calculate the time difference between the two and append to this mac's total time
            this_entry = @mac_times[entry.mac]
            if this_entry
              this_time = this_entry[:time]
            else
              this_time = 0
            end
            @mac_times[entry.mac] = {:mac => entry, :time => (entry.created_at - last_active.created_at) + this_time}
          else
            # No pair found; discard.
            last_active = nil
          end
        end
      end
    end
    @mac_times_sorted = @mac_times.sort{|a,b| b.last[:time] <=> a.last[:time] }
    @most_active_mac = nil
    @runner_up_mac = nil
    @mac_times_sorted.each do |mac_time|
      unless @most_active_mac
        this_mac = Mac.find_by_mac(mac_time.first)
        unless this_mac.hidden
          @most_active_mac = this_mac
          @most_active = mac_time
        end
      else
        unless @runner_up_mac
          this_mac = Mac.find_by_mac(mac_time.first)
          unless this_mac.hidden
            @runner_up_mac = this_mac
            @runner_up = mac_time
          end
        end
      end
    end
  end

  #@active_macs = Mac.where(:active => true, :hidden => false)
  #@active_macs += Mac.where(:active => true, :hidden => nil)

  # De-dupe users for the public
  if can? :update, Mac then
    @active_macs = Mac.where("macs.active = ? AND (macs.hidden IS NULL OR macs.hidden = ?)", true, false).includes(:user).order("users.name ASC")
  elsif user_signed_in? then
    @active_macs = Mac.where("macs.active = ? AND (macs.hidden IS NULL OR macs.hidden = ?)", true, false).includes(:user).order("users.name ASC").group("users.name")
  else
    @active_macs = Mac.select("mac, note, user_id").where("macs.active = ? AND (macs.hidden IS NULL OR macs.hidden = ?)", true, false).joins(:user).order("users.name ASC").group("users.name, mac, note, user_id")
  end

  @hidden_macs = Mac.where("macs.active = ? AND macs.hidden = ?", true, true).order("note ASC")

  @all_macs = Mac.find(:all, :order => "LOWER(mac)")

  respond_to do |format|
    format.html
    format.json {
      @filtered_macs = Mac.select("macs.mac, users.name, macs.note").where("macs.active = ? AND (macs.hidden IS NULL OR macs.hidden = ?)", true, false).joins(:user)
      render :json => @filtered_macs
    }
  end
end

  def history
    authorize! :read_details, Mac
    begin
      @start_date = DateTime.parse(params[:start])
      @end_date = DateTime.parse(params[:end])
    rescue
      @start_date = DateTime.now - 2.weeks
      @end_date = DateTime.now
    end

    @mac_logs_by_hour = MacLog.where("created_at > ? AND created_at < ?", @start_date, @end_date).group_by{|m| m.created_at.beginning_of_hour}
    @mac_log_graph = []
    mac_running_balance = 0
    lowest_balance = 0
    @mac_logs_by_hour.each do |time, mac_log|
      mac_log.each do |entry|
        # Add one computer for activate, subtract one for deactivate
        if entry.action == "activate"
          mac_running_balance += 1
        elsif entry.action == "deactivate"
          mac_running_balance -= 1
        end
        # Keep track of the lowest number in the graph
        if mac_running_balance < lowest_balance
          lowest_balance = mac_running_balance
        end
      end
      @mac_log_graph << [time.to_time.to_i*1000,mac_running_balance]
    end

    if lowest_balance != 0
      # Subtract a negative balance to raise everything
      @mac_log_graph = @mac_log_graph.map{ |time,balance| [time, balance - lowest_balance] }
    end

    respond_to do |format|
      format.html
      format.json { render :json => @mac_log_graph }
    end
  end

  # GET /macs/1
  # GET /macs/1.json
  def show
    @mac = Mac.find(params[:id])
    @mac_logs = MacLog.where(:mac => @mac.mac)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @macs }
    end
  end

  # GET /macs/new
  # GET /macs/new.json
  def new
    @mac = Mac.new
    if can? :manage, Mac then
      @users = User.accessible_by(current_ability).sort_by(&:name)
    else
      @users = [current_user]
    end

    respond_to do |format|
      format.html # new.html.erb
      format.json { render :json => @mac }
    end
  end

  # GET /macs/1/edit
  def edit
    @mac = Mac.find(macs_params)
    if can? :manage, Mac then
      @users = User.accessible_by(current_ability).sort_by(&:name)
    else
      @users = [current_user]
    end
  end

  # POST /macs
  def create
    @mac = Mac.new(macs_params)
    @existing_mac = Mac.find_by_mac(@mac.mac)
        if can? :manage, Mac then
          @users = User.accessible_by(current_ability).sort_by(&:name)
        else
          @users = [current_user]
        end

      if @existing_mac.present?
        if @existing_mac.user_id.nil?
          redirect_to edit_mac_path(@existing_mac), :notice => 'This MAC already exists, edit it here:'
        else
@mac.errors.add(:user,"for this MAC is already set to #{@existing_mac.user.name} -- please contact them or an admin if this is incorrect.")
          render :action => "new"
        end
      else

        respond_to do |format|
          if @mac.save
            format.html { redirect_to macs_path, :notice => 'MAC was successfully created.' }
            format.json { render :json => @mac, :status => :created, :location => @mac }
          else
            format.html { render :action => "new" }
            format.json { render :json => @mac.errors, :status => :unprocessable_entity }
          end
        end
      end
  end

  # PUT /macs/1
  # PUT /macs/1.json
  def update
    #Log who updated this
    @mac = Mac.find(params[:id])
    @mac.assign_attributes(params[:mac])
    #@mac.user_id = params[:mac][:user_id]
    authorize! :update, @mac

    if can? :manage, Mac then
      @users = User.accessible_by(current_ability).sort_by(&:name)
    else
      @users = [current_user]
    end

    respond_to do |format|
      if @mac.save
        format.html { redirect_to macs_path, :notice => 'MAC was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @mac.errors, :status => :unprocessable_entity }
      end
    end
  end

def arp_lookup
  @ip = request.env['REMOTE_ADDR']
  @arp = /([0-9A-F]{2}[:-]){5}([0-9A-F]{2})/i.match(%x(arp -a | grep #{@ip}))
end

def scan
Rails.logger.info "starting scan..."
  # Command line arguments
  options = {};
  OptionParser.new { |opts|
    opts.banner = "Usage: pamela-scanner.rb --interface=en0"

    options[:verbose] = true
    opts.on("v", "--verbose", "Run verbosely") { |verbose|
      options[:verbose] = verbose
    }

    options[:interface] = "eth0"
    opts.on("i", "--interface=interface", "Network Interface") { |interface|
      options[:interface] = interface
    }

    options[:max_age] = 20
    opts.on("a", "--max-age=minutes", "Minutes to keep expired macs active") { |max_age|
      options[:max_age] = max_age.to_i
    }

    options[:db_host] = "configure_me"
    opts.on("r", "--db-host=host", "Database Host") { |host|
      options[:db_host] = host
    }

    options[:db_name] = "configure_me"
    opts.on("n", "--db-name=name", "Database Name") { |name|
      options[:db_name] = name
    }

    options[:db_user] = "configure_me"
    opts.on("u", "--db-user=user", "Database User") { |user|
      options[:db_user] = user
    }

    options[:db_password] = "configure_me"
    opts.on("p", "--db-password=password", "Database Password") { |password|
      options[:db_password] = password
    }

  }.parse!

  # Open the database
  #ActiveRecord::Base::establish_connection(
  #  :adapter  => "mysql2",
  #  :host     => options[:db_host],
  #  :database => options[:db_name],
  #  :username => options[:db_user],
  #  :password => options[:db_password])

  #class Mac < ActiveRecord::Base
  #end

  #class MacLog < ActiveRecord::Base
  #end

  # Scan the network for mac addresses
  macs = {};
  command = sprintf("arp-scan -R --interface=%s --localnet", options[:interface])
  if options[:verbose]
    Rails.logger.info "Running [#{command}]"
  end
  IO.popen(command) { |stdin|
    result = stdin.read()
    result.lines.each { |line|
      Rails.logger.info "Reading stdin: "+line.inspect
      next if line !~ /^([\d\.]+)\s+([[:xdigit:]:]+)\s/;
      macs[($2).downcase] = ($1).downcase;
    }
    Rails.logger.info "STDIN:"+result.lines.count.inspect
    @macs = macs.dup # make a copy for output in the view
    Rails.logger.info "MACS:"+@macs.inspect
  }

  # Scan the existing macs and update each record as necessary
  Mac.find(:all).each { |entry|
    mac = entry.mac.downcase
    ip = entry.ip
    if macs.has_key?(mac) # if our scan shows this mac
      if ! entry.active || ! entry.since
        Rails.logger.info "Activating #{mac} at #{ip}" if options[:verbose]
        entry.since = Time.now
        MacLog.new(:mac => mac, :ip => ip, :action => "activate").save
      end
      entry.active = 1
      entry.ip = ip
      entry.refreshed = Time.now
      entry.save
      macs.delete(mac)
      next
    end

    # Entry is no longer current
    if entry.active
      ageMinutes = ((Time.now - entry.refreshed)/60).to_i
      next if ageMinutes < options[:max_age]
      Rails.logger.info "Deactivating #{mac}, #{ageMinutes} minutes old" if options[:verbose]
      entry.active = 0
      entry.save
      MacLog.new(:mac => mac, :ip => ip, :action => "deactivate").save
    end
  }

  # Add entries for any macs not already in the db
  macs.each { |mac, ip|
    Rails.logger.info "Activating new entry #{mac} at #{ip}" if options[:verbose]
    Mac.new(:mac => mac, :ip => ip, :active => 1, :since => Time.now, :refreshed => Time.now).save
    Rails.logger.info MacLog.new(:mac => mac, :ip => ip, :action => "activate").save
  }

@log = MacLog.all

end #def scan


def import

require 'csv'

csv_text = File.read('mac_log.csv')
csv = CSV.parse(csv_text)

@output = []

csv.each do |row|
  @output += [row[1], Mac.create({:mac => row[0], :note => row[1], :hidden => row[2]}) ]
end

end

  private

  def macs_params
    attr_accessible :active, :ip, :mac, :refreshed, :since, :hidden, :note, :user_id
  end
end
