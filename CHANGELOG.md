# Changelog

### v0.1.7

* Add support for usernames other than 'ubuntu' (defaulting to 'ubuntu' will be deprecated soonish)

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

