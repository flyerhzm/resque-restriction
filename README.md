resque-restriction
===============

[![AwesomeCode Status for flyerhzm/resque-restriction](https://awesomecode.io/projects/ebc1a493-78f5-4d8a-9bb7-097fdaa657ec/status)](https://awesomecode.io/repos/flyerhzm/resque-restriction)
[![Build Status](https://secure.travis-ci.org/flyerhzm/resque-restriction.png)](http://travis-ci.org/flyerhzm/resque-restriction)

Resque Restriction is a plugin for the [Resque](https://github.com/resque/resque) queueing system. It adds two functions:

1. it will limit the execution number of certain jobs in a period time. For example, it can limit a certain job can be executed 1000 times per day, 100 time per hour and 30 times per 300 seconds.

2. it will execute the exceeded jobs at the next period. For example, you restrict the email sending jobs to run 1000 times per day. If your system generates 1010 email sending jobs, only 1000 email sending jobs can be executed today, and the other 10 email sending jobs will be executed tomorrow.

Resque Restriction requires Resque 1.7.0.

*Please make sure your workers are checking restriction_xxx queue.*.
e.g., if you add restriction plugin to high_priority queue, you need to
check restriction_high_priority queue.

Attention
---------

The `identifier` method is renamed to `restriction_identifier` to solve the confliction with resque-retry from version 0.3.0.

Install
-------

Add this line to your application's Gemfile:

```ruby
gem 'resque-restriction'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install resque-restriction

To use
------

It is especially useful when a system has an email invitation resque job, because sending emails too frequentyly will be treated as a spam. What you should do for the InvitationJob is to inherit it from Resque::Plugins::RestrictionJob class and add restrict definition. Example:

```ruby
class InvitationJob
  extend Resque::Plugins::Restriction

  restrict :per_day => 1000, :per_hour => 100, :per_300 => 30

  # rest of your class here
end
```

That means the InvitationJob can not be executed more than 1000 times per day, 100 times per hour and 30 times per 300 seconds.  All restrictions have to be met for the job to execute.

The argument of restrict method is a hash, the key of the hash is a period time, including :concurrent, :per_second, :per_minute, :per_hour, :per_day, :per_week, :per_month, :per_year, and you can also define any period like :per_300 means per 300 seconds. The value of the hash is the job execution limit number in a period.  The :concurrent option restricts the number of jobs that run simultaneously.

Advance
-------

You can also add customized restriction as you like. For example, we have a job to restrict the facebook post numbers 40 times per user per day, we can define as:


```ruby
class GenerateFacebookShares
  extend Resque::Plugins::Restriction

  restrict :per_day_and_user_id => 40

  # rest of your class here
  def self.perform(options)
    # options["user_id"] exists
  end
end
```

```ruby
class GenerateFacebookShares
  extend Resque::Plugins::Restriction

  restrict :per_day => 40

  def self.restriction_identifier(options)
    [self.to_s, options["user_id"]].join(":")
  end

  # rest of your class here
end
```

options["user_id"] returns the user's facebook uid, the key point is that the different restriction_identifiers can restrict different job execution numbers.


Contributing
------------

Bug reports and pull requests are welcome on GitHub at https://github.com/flyerhzm/resque-restriction.
