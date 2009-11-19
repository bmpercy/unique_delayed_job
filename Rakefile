require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "unique_delayed_job"
    gemspec.summary = "Class for inserting delayed jobs without duplication"
    gemspec.description = <<DESC
Class for creating delayed jobs that can be de-duped with existing delayed jobs
already in the delayed jobs table. You just specify some additional columns on
your delayed_jobs table and set them to have uniqueness constraints. Then
specify these column values when you create a UniqueDelayedJob and if a
duplicate key is raised on insert, then the insert will just be ignored. There
are factory methods for creating a delayed job in the following ways:
* with a delayed job handler class (one that responds to perform())
* with an object, method and method arguments
* with a code block
DESC
    gemspec.email = "percivalatumamibuddotcom"
    gemspec.homepage = "http://github.com/bmpercy/unique_delayed_job"
    gemspec.authors = ['Brian Percival']
    gemspec.add_dependency 'delayed_job', '>= 1.2.0'
    gemspec.files = ["unique_delayed_job.gemspec",
                     "[A-Z]*.*",
                     "lib/**/*.rb"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
