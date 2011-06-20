# Developing with Dew

## Code Layout

The new codebase follows a Rails-like layout::

  * `env.rb` : load application libraries
  * `features` : Cucumber features / integration tests
  * `lib` : code libraries
  * `lib/models` : models (eg Environment, Server)
  * `lib/actions` : actions (eg CreateAMI)
  * `lib/tasks` : Rake tasks
  * `script` : environment management and deployment scripts
  * `script/shared` : shared code between scripts
  * `spec` : unit tests

## Conventions

  * Models inspect and act on resources.
  * Controllers co-ordinate actions.
  * Scripts present information and ask for input.
  * 'Fat' controllers are OK!
  * Put procedural logic in controllers, not models.
  * Calling one controller from another is considered OK!
  * 100% code coverage is required, except for scripts.
  * Spike new things as a script, then rewrite using TDD principles
  * Cucumber tests are more regression than progression: most of the time they'll be too slow to use true BDD principles.

## Tests

Run `cucumber` to run most integration tests. Run `cucumber --profile=all` to run all tests, including the ones that take a really long time.

Run `rake spec:covered` to run the unit tests and check code coverage.

There are three builds configured in Hudson: `AWS`, `AWS - Slow` and `AWS - Stress Test`. `AWS` should always be green. `AWS - Slow` is on best efforts and should not block commits. `AWS - Stress Test` is `AWS - Slow` run ten times against the `release` branch.

### Warning!

Running `cucumber` with a correctly configured `development.yaml` will drain whichever credit card you've attached to that account!

## Documentation

See `TODO.md` for work that needs to be completed.

Keep `CHANGELOG.md` up to date with any public-facing changes.
