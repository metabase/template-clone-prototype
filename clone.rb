# dependencies
require 'yaml'
require 'nanoid'
require 'slop'
require 'logger'

@log = Logger.new("log-#{Time.now}.txt")

@opts = Slop.parse do |o|
  o.string '-y', '--yaml-files', 'the directory containing the yaml files', required: true
  o.string '-s', '--source-datasource', 'the datasource to be replaced', required: true
  o.string '-t', '--target-datasource', 'the datasource to replace with', required: true
  o.string '-n', '--new-collection-name', 'the new name for the top collection', default: nil
  o.bool '-d', '--duplicate', 'duplicate the collections', default: false
  o.on '--help' do
    puts o
    exit
  end
end


# arguments
#@source_dir = File.absolute_path(ARGV[0]) # original files
#@source_datasource = ARGV[1] # original datasource
#@target_datasource = ARGV[2] # modified datasource
#@new_top_collection_name = ARGV[3]
#@duplicate = ARGV[4]=="--duplicate"

@num_collections = 0
@num_dash = 0
@num_questions = 0
@num_models = 0

########
# TODO: Go through each card file in the source directory

# Example directory: site-2024-07-30_17-44/collections/_s2ntQI8-FhJGatZY3nEn_automatically_generated_dashboards/**/cards/*.yaml
@entity_id_map = {}
def entity_id_for(entity_id, remap=true)
  raise "Attempting to map for empty entity_id" if entity_id.nil? || entity_id.empty?
  if @entity_id_map.has_key?(entity_id)
  elsif remap
    @entity_id_map[entity_id] = Nanoid.generate
    @log.debug "Generated new entity ID: #{entity_id} -> #{@entity_id_map[entity_id]}"
  else
    # do not map to new entity id
    @entity_id_map[entity_id] = entity_id
  end
  return @entity_id_map[entity_id]
end

def update_entity_ids(entity, type=nil, update_parent=true)
  if type=="question" || type=="model" || type=="dashboard"
    entity["entity_id"] = entity_id_for(entity["entity_id"]) if entity.has_key?("entity_id") 
    entity["serdes/meta"][0]["id"] = entity_id_for(entity["serdes/meta"][0]["id"]) if entity["serdes/meta"].is_a?(Array) && entity["serdes/meta"][0].has_key?("id")
    entity["collection_id"] = entity_id_for(entity["collection_id"]) if entity.has_key?("collection_id")
  end
  if type=="question" || type=="model"
    traverse(entity) do |node|
      if node && node.is_a?(Hash) && node.has_key?("source-table") && node["source-table"].is_a?(String)
        node["source-table"] = entity_id_for(node["source-table"])
      end
    end
  end
  if type=="dashboard"
    # Update entity ids of dashcards
    entity.has_key?("dashcards") && entity["dashcards"].each do |dashcard|
      dashcard["entity_id"] = entity_id_for(dashcard["entity_id"]) if dashcard.has_key?("entity_id")
      dashcard["card_id"] = entity_id_for(dashcard["card_id"]) if dashcard.has_key?("card_id") && !dashcard["card_id"].nil?
      dashcard.has_key?("parameter_mappings") && dashcard["parameter_mappings"].each do |param_map|
        param_map["card_id"] = entity_id_for(param_map["card_id"]) if param_map.has_key?("card_id")
        traverse(param_map) do |node|
          if node.is_a?(Array) && node[0] == @opts["source-datasource"]
            node[0] = @opts["target-datasource"]
          end
        end
      end
      if dashcard["visualization_settings"].has_key?("click_behavior") && dashcard["visualization_settings"]["click_behavior"].has_key?("targetId")
        dashcard["visualization_settings"]["click_behavior"]["targetId"] = entity_id_for(dashcard["visualization_settings"]["click_behavior"]["targetId"])
      end
    end
  elsif type=="collection"
    entity["entity_id"] = entity_id_for(entity["entity_id"]) if entity.has_key?("entity_id") 
    entity["serdes/meta"][0]["id"] = entity_id_for(entity["serdes/meta"][0]["id"]) if entity["serdes/meta"].is_a?(Array) && entity["serdes/meta"][0].has_key?("id")
    entity["parent_id"] = entity_id_for(entity["parent_id"]) if update_parent && !entity["parent_id"].nil?
  end
end

def update_datasource(entity)
  if entity.has_key?("database_id") && entity["database_id"] == @opts["source-datasource"]
    entity["database_id"] = @opts["target-datasource"]
  end
  if entity.has_key?("dataset_query") && entity["dataset_query"].has_key?("database") && entity["dataset_query"]["database"] == @opts["source-datasource"]
    entity["dataset_query"]["database"] = @opts["target-datasource"]
  end
  for key in ["table_id", "dataset_query"] do
    if entity.has_key?(key) && entity[key].is_a?(Array) && entity[key][0] == @opts["source-datasource"]
      entity[key][0] = @opts["target-datasource"]
    end  
  end
  traverse(entity) do |node|
    if node.is_a?(Array) && node[0] == @opts["source-datasource"]
      node[0] = @opts["target-datasource"]
    end
  end
end

def traverse(obj,parent=nil, &blk)
  case obj
  when Hash
    blk.call(obj,parent) # alberto
    obj.each do |k,v| 
      blk.call(k,parent)
      # Pass hash key as parent
      traverse(v,k, &blk) 
    end
  when Array
    blk.call(obj,parent) # alberto
    obj.each {|v| traverse(v, parent, &blk) }
  else
    blk.call(obj,parent)
  end
 end

## Update top parent collection
Dir.glob("#{@opts["yaml-files"]}/collections/*/*.yaml") do |yaml_file|
  @log.debug "Processing top level collection: #{yaml_file}"
  entity = YAML.load_file(yaml_file)
  update_entity_ids(entity, "collection", false) if @opts[:duplicate]

  # Update name and slug
  entity["name"] = @opts["new-collection-name"]
  entity["slug"] = @opts["new-collection-name"].downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  entity["serdes/meta"][0]["label"] = @opts["new-collection-name"].downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  @num_collections+=1
  File.write(yaml_file, entity.to_yaml)
  @log.debug "Wrote #{yaml_file}"
end

## Update everything else
Dir.glob("#{@opts["yaml-files"]}/collections/*/*/**/*.yaml") do |yaml_file|
  @log.debug "Processing #{yaml_file}"
  entity = YAML.load_file(yaml_file)

  if entity["type"]=="question"
    update_entity_ids(entity, "question") if @opts[:duplicate]
    update_datasource(entity)
    @num_questions+=1
  elsif entity["type"]=="model"
    update_entity_ids(entity, "model") if @opts[:duplicate]
    update_datasource(entity)
    @num_models+=1
  elsif  entity["serdes/meta"][0]["model"]=="Dashboard"
    update_entity_ids(entity, "dashboard") if @opts[:duplicate]
    @num_dash+=1
  elsif  entity["serdes/meta"][0]["model"]=="Collection"
    update_entity_ids(entity, "collection") if @opts[:duplicate]
    @num_collections+=1
  end
  File.write(yaml_file, entity.to_yaml)
  @log.debug "Wrote #{yaml_file}"
end

@log.debug "Processed #{@num_collections} collections, #{@num_dash} dashboards, #{@num_questions} questions."

@log.debug @entity_id_map.to_yaml
