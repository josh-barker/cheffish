class Chef::Provider::CheffishDataBagItem < Cheffish::ChefProviderBase

  def whyrun_supported?
    true
  end

  action :create do
    differences = json_differences(current_json, new_json)

    if current_resource_exists?
      if differences.size > 0
        description = [ "update data bag item #{new_resource.id} at #{rest.url}" ] + differences
        converge_by description do
          rest.put("data/#{new_resource.data_bag}/#{new_resource.id}", normalize_for_put(new_json))
        end
      end
    else
      description = [ "create data bag item #{new_resource.id} at #{rest.url}" ] + differences
      converge_by description do
        rest.post("data/#{new_resource.data_bag}", normalize_for_post(new_json))
      end
    end
  end

  action :delete do
    if current_resource_exists?
      converge_by "delete data bag item #{new_resource.id} at #{rest.url}" do
        rest.delete("data/#{new_resource.data_bag}/#{new_resource.id}")
      end
    end
  end

  def load_current_resource
    begin
      @current_resource = json_to_resource(rest.get("data/#{new_resource.data_bag}/#{new_resource.id}"))
    rescue Net::HTTPServerException => e
      if e.response.code == "404"
        @current_resource = not_found_resource
      else
        raise
      end
    end
  end

  def new_json
    @new_json ||= begin
      json = super
      # Apply modifiers
      json['raw_data'] = apply_modifiers(new_resource.raw_data_modifiers, json['raw_data'])
      json
    end
  end

  #
  # Helpers
  #
  # Gives us new_json, current_json, not_found_json, etc.
  require 'chef/chef_fs/data_handler/data_bag_item_data_handler'

  def resource_class
    Chef::Resource::CheffishDataBagItem
  end

  def data_handler
    Chef::ChefFS::DataHandler::DataBagItemDataHandler.new
  end

  def keys
    {
      'id' => :id,
      'data_bag' => :data_bag,
      'raw_data' => :raw_data
    }
  end

  def not_found_resource
    resource = super
    resource.data_bag new_resource.data_bag
    resource
  end

  def fake_entry
    FakeEntry.new("#{new_resource.id}.json", FakeEntry.new(new_resource.data_bag))
  end

end