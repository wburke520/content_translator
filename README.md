# NOTE: Readme Driven Development: May not do what the readme says yet.

**Status**: We are sending some content both ways between WTI and a production system. There are some error handling, it has error reporting (to honeybadger) and messages are persisted, but it's not quite 1.0 yet.

[CircleCi](https://circleci.com/gh/barsoom/content_translator)

## Content translator

A webservice to translate content using WebTranslateIt and keep track of mappings to local ids.

This app is designed with reliability in mind. It will retry calls both to the client app and to the WTI service as needed.

This app follows the model of [gridlook](https://github.com/barsoom/gridlook) to keep things simple: one deployment per client project.

### Sending content changes to this app

Content is sent to this app by HTTP calls. Create and update is POST, destroy is DELETE.

These calls can be made multiple times without causing any problems, so design your app to continue retrying the requests until you get a 200 response (e.g. instead of a timeout).

    POST   /api/texts token=authtoken identifier="help_item_25" name="question" value="What is elixir?" locale=en
    DELETE /api/texts token=authtoken identifier="help_item_25" name="question"

See the configuration section for how to setup the token.

### Receiving changes from this app

Changes are sent back using a webhook. The webhook retries until it get's a 200 response or 3 hours has passed.

The value of `payload` is form encoded JSON:

      payload=%22text%22%3A%22Vad+%C3%A4r+elixir%3F%22%2C%22name%22%3A%22question%22%2C%22locale%22%3A%22sv%22%2C%22identifier%22%3A%22help_item_25%22%7D"

Which looks like this when not form encoded:

      {"text":"Vad är elixir?","name":"question","locale":"sv","identifier":"help_item_25"}

In rails you can do this:

      payload = JSON.parse(params[:payload])
      payload["name"] # => "question"

See the configuration section for how to setup webhook URLs.

## Set up

### Set up a project in WebTranslateIt

[Create a project](https://webtranslateit.com/en/projects/new) and:

0. Set up a source language
0. Add languages you want to translate to

### Deploy this app to heroku

    heroku apps:create some-content-translator --region eu --buildpack https://github.com/HashNuke/heroku-buildpack-elixir.git
    heroku config:set MIX_ENV=prod
    heroku config:set HOSTNAME=some-content-translator.herokuapp.com

    # NOTE: If you add more config variables, then also list them in elixir_buildpack.config
    heroku config:set SECRET_KEY_BASE=$(elixir -e "IO.puts :crypto.strong_rand_bytes(64) |> Base.encode64")
    heroku config:set AUTH_TOKEN=$(elixir -e "IO.puts Regex.replace(~r/[^a-zA-Z0-9]/, (:crypto.strong_rand_bytes(64) |> Base.encode64), \"\")")
    heroku config:set CLIENT_APP_WEBHOOK_URL="https://example.com/api/somewhere?your_auth_token=123"
    heroku config:set WTI_PROJECT_ID=123
    heroku config:set WTI_PROJECT_TOKEN=token # must be the read-write token
    heroku config:set HONEYBADGER_API_KEY=your-api-key

    heroku addons:add rediscloud:25

    git push heroku master

### Configure check that it works

0. Configure the webhook url in WTI to something like `https://YOUR_APP_NAME.herokuapp.com/api/wti_webhook?token=the-auth-token-for-this-app`
0. Configure the client app to send content to this app
0. Change something in your client app, see that it appears in WTI
0. Translate something in WTI and see if the content is updated in your app

## TODO

### Minimal app

- [x] Write configuration section docs
- [x] Get CI and deploy working
- [x] Get automatic deploy working
- [x] Set up a way to get WTI webhooks to the dev box
- [x] Authentication
- [x] handle text update
  - [x] Set up client app in dev to post content to this app
  - [x] Figure out how to call the WTI API in elixir
  - [x] Handle empty texts (seems the api defaults the text to the key-name?)
- [x] ensure all our texts work, next to debug: help_item_31, de
- [x] handle text delete
- [x] handle wti webhooks
  - [x] auth
  - [x] consider removing redis, if the key name could be reliable enough, maybe `: ` between indentifier and name, like `help_item_31: question`. in that case, refuse input of ":" in either field
  - [x] be able to parse the request
  - [x] don't do anything when the webhook is a result of a update from this app
  - [x] post to the client app

### Reliable app

- [x] Error reporting to honeybadger
- [ ] Reliability
  - [x] be able to work though stored requests, e.g. background job (make app restart safe)
  - [x] test stored background jobs feature in prod
  - [x] verify that all our content can still be sent to WTI (as their validations evolve over time)
  - [ ] retries
    - **note** I plan to solve most of the items below by building [exqueue](https://github.com/joakimk/exqueue)
    - [ ] don't report errors until we've retried enough, retrying is expected
    - [ ] ensure timeouts in bg jobs means they are retried
    - [ ] retry posting to the client app as the readme says
      - explore how messages are handled on worker restart, does it retry? exponential standoff possible?
    - [ ] retry posting to wti
    - [ ] ensure the source language is always posted first to avoid validation issues (or: always post in the order it was received, even when retrying)
  - [ ] figure out testing
- [ ] Configure internal chat notifications for honeybadger errors

### More

- [ ] See if %{placeholder} validations could be turned off for content translations (apparently you can skip those in the WTI UI)
- [ ] Restart the redis process if it fails? Add to supervisor somehow?
- [ ] Reset redis after each redis test instead of in ContentTranslator at boot
- [ ] Error reporting that is grouped correctly in honeybadger
- [ ] Prevent ":" in either "identifier" or "name" as that would cause problems with TranslationKey
- [ ] Add step to readme for removing the default postgres DB so you won't think it might be used
- [x] Refactor WtiTranslationApi. The request parts could probably live elsewhere.
- [ ] Screenshots of WTI in readme, diff handling, etc
- [ ] Show app status on internal dashboard
- [ ] Open source generic parts of the ruby client
- [ ] Don't push anything to WTI that hasn't changed (but if this app does not keep any state that could be hard, could leave that up to the client app)
- [ ] Would it be easy to setup a Dockerfile and post this to dockerhub? Easy alternative to heroku.
  - How to handle config?

## Development

    mix deps.get
    mix test
    mix phoenix.server

### Gotchas

All strings are stripped of whitespace at the end because WTI won't accept strings ending in newlines.

### Seeing 406 errors from WTI?

WTI does some validation. One example of this is that the translated text must end with a newline if the source test does. One way of getting around this is to not let the user edit the translated text in the source system. If all translations are done in WTI the user has to deal with it's validations before being able to save.

I've asked the WTI maintainer to return the actual validation error in the API response. At the time of writing it just says that something is wrong.

### Credits and license

By [Barsoom](http://barsoom.se) under the MIT license:

>  Copyright © 2015 Barsoom AB
>
>  Permission is hereby granted, free of charge, to any person obtaining a copy
>  of this software and associated documentation files (the "Software"), to deal
>  in the Software without restriction, including without limitation the rights
>  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
>  copies of the Software, and to permit persons to whom the Software is
>  furnished to do so, subject to the following conditions:
>
>  The above copyright notice and this permission notice shall be included in
>  all copies or substantial portions of the Software.
>
>  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
>  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
>  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
>  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
>  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
>  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
>  THE SOFTWARE.
