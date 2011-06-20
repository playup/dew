Dew is a layer between the ground and fog, which is used to access the cloud.

It includes:
  * one command `dew`, with subcommands eg. `environments`, `amis`

## Installation

First install the dew gem

    $ [sudo] gem install dew

Then create all the config files it needs.

    $ git clone git@github.com:playup/dew-config.git ~/.dew

or

    $ mkdir -p ~/.dew/accounts
    $ cat > ~/.dew/accounts/development.yaml
    aws:
      user_id: xxxx-xxxx-xxxx
      access_key_id: YYYYYYYYYYYYYYYYYYYY
      secret_access_key: ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ


Then run the dew command

    $ dew --help

## Creating a Simple Environment

## Creating an AMI for a new Environment

## Deploying to an Environment

## Developing with Dew

Read `HACKING.md`
