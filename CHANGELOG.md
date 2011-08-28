# Changelog

### v0.2.1

* Changed `env ssh` command to optionally accept a command to run
* Added `env scp` command

### v0.1.9

* Apache deploy template now uses port 8080 for HTTPd to enable allow for varnish integration.
* Deploy uses `mktemp` on the destination system instead of always writing the config file to `/tmp/apache.conf`
* Deploy obtains the working directory for the deployed application rather than simply guessing it

### v0.1.8

* `deploy passenger` will now `ln -sf database.dew.yml database.yml` for those projects that don't wan't to put a `database.yml` in their repo
* Add `--create-database` option to `deploy passenger` to force a db creation attempt
* Fix issue with `clamp` versions `>= 0.2.2`

### v0.1.7

* Add support for usernames other than 'ubuntu' (defaulting to 'ubuntu' will be deprecated soonish)
* `dew environments` is now `dew env`
* Add `--args` option to `dew env run`

### v0.1.6

* Re-order requires in `lib/dew.rb` to improve gem load speed
* Add `DEW_REGION`, `DEW_ACCOUNT` and `DEW_VERBOSE` environment variables

### v0.1.4

* Added `dew environments run` command to run scripts or commands on instances in the environment

### v0.1.3

* `PUGE_DB_*` environment variables are now `DB_*` variables
* Add --server-name method to passenger deploy mechanism to allow for multiple-site instances
* Add --no-passenger hack to deploy static content in a passenger-like way
* Add check for build script in script/build
* Add --ssl-certificate & --ssl-private-key options to passenger deploy

### v0.1.2

* Bump up ssh timeout from 2 to 3 minutes.
* Update inform gem and clean up output a bit

### v0.1.1

* Added --version
* Make sure works with ruby 1.8.7
* Add example/ directory
* Update README.md
* BUGFIX #1: Undefined method 'agree' when trying to destroy environment

### v0.1.0

* Created dew and released gem into the wild

