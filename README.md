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

1. clone a collection (to import it within the origin Metabase instance), optionally updating the underlying data source
2. Change the data source of a collection
   
## Limitations

It can only swap out one data source at a time. If the items in your collections depend on multiple data sources, you might have to do several runs. This scenario has not been tested yet.

## Example usage

1. Locate the ID of the collection to use as template. In this case, it's 9 and export it via serialization API:

```sh
curl \        -H 'x-api-key: API_KEY' \  
-X POST 'http://localhost:3000/api/ee/serialization/export?settings=false&data_model=false&collection=9' \                                      
-o metabase_data.tgz
```

2. Extract tarball

```sh
tar xzf metabase_data.tgz
```

3. Run this tool pointing to the directory extracted from the tarball, and providing the source and target names for the data source names.

If you are planning to load the result into the same instance, you will want to add the `--duplicate` parameter, otherwise you will override the source collection on import.

```sh
ruby clone.rb -y foobar-2024-08-09_20-57 -s DVD Rental -t DVD Rental 2 -n Super fancy new collection -d
```
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
