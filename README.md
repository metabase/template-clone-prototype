# About

This is a prototype to do deep copies of Metabase collections.

## Requirements
* A Metabase instance with a Pro license, to unlock the serialization feature to import/export the collection
* An API key, which can be created on Metabase at `/admin/settings/authentication/api-keys` 
* A collection you want to clone or change the data source for 

## Installation

* Make sure you have Ruby installed
* Check out this repo with `git clone https://github.com/metabase/template-clone-prototype.git`
* Install the dependencies with `bundle install`
* Test if the dependencies are satisfied by running `ruby clone.rb --help`.

## Supported use cases and usage

1. Clone a collection, optionally updating the underlying data source
2. Change the data source of a collection without duplicating or renaming it
   
## Limitations

It can only swap out one data source at a time. If the items in your collections depend on multiple data sources, you might have to do several runs. This scenario has not been tested yet.

## Example usage

1. Locate the ID of the collection to use as template. In this example it's 9. Export the collection via serialization API by specifying `collection=ID`. 

```sh
curl \        -H 'x-api-key: API_KEY' \  
-X POST 'http://localhost:3000/api/ee/serialization/export?settings=false&data_model=false&collection=9' \                                      
-o metabase_data.tgz
```

2. Extract data from the tarball. This will create a directory with YAML files and subdirectories inside of it. The directory name is based on the site name and timestamp of the export.

```sh
tar xzf metabase_data.tgz
```

3. Run this tool pointing to the directory extracted from the tarball, and providing the source and target names for the data source names.

If want ato load a copy into the same instance, you will want to use the following parameters:
* the `--source-datasource` and `--target-datasource` to swap out the data source (these are required for now, so if you don't want to change the data source just use the same data source name in both)
* the `--duplicate` parameter if you want a copy, and omit this parameter if you want to overwrite the collection changing it's datasource
* the `--new-collection-name` to give the new copy a different name or to change the name of the collection

```sh
ruby clone.rb --yaml-files foobar-2024-08-09_20-57 --source-datasource "Old database" --target-datasource "New database" --new-collection-name "Super fancy new collection" --duplicate
```

* `--yaml-files` **required**, should point to the directory you extracted from the tarball
* `--source-datasource` **required**, the display name of the data source to replace (check `/admin/databases` on Metabase)
* `--target-datasource` **required**, the display name of the data source to replace with (check `/admin/databases` on Metabase)
* `--new-collection-name` **optional**, the new name for the collection 
* `--duplicate` **optional**, will create new entity IDs for all items to clone entire collection and its contents

4. Create a tarball with the modified files

```sh
tar -czf metabase_data_modified.tgz foobar-2024-08-09_20-57
```

5. Import the tarball via serialization API
   
```sh
curl -X POST \  -H 'x-api-key: API_KEY' \
  -F file=@metabase_data_modified.tgz \
  'http://localhost:3000/api/ee/serialization/import' \
  -o -
```

## Use cases and parameters

### Change the datasource from prod to dev

```sh
ruby clone.rb --yaml-files foobar-2024-08-09_20-57 --source-datasource "Production" --target-datasource "Development" --new-collection-name "Collection now pointing to dev"
```

### Clone the collection without changing the datasource

```sh
ruby clone.rb --yaml-files foobar-2024-08-09_20-57 --source-datasource "Production" --target-datasource "Production" --new-collection-name "Customer collection copy" --duplicate
```

### Clone the collection, changing the datasource

```sh
ruby clone.rb --yaml-files foobar-2024-08-09_20-57 --source-datasource "Production" --target-datasource "Customer A Production" --new-collection-name "Customer A collection" --duplicate
```
