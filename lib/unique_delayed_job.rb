# allows for specifying additional columns on the delayed_jobs table to help
# prevent duplicate delayed jobs from being entered into the queue...but still
# keep an easy interface to enqueuing delayed jobs
#-------------------------------------------------------------------------------
class UniqueDelayedJob

  # factory method to create a new UniqueDelayedJob from a delayed job handler
  # object (see delayed job documentation for requirements)
  #
  # arguments:
  #    - handler: the delayed jobs handler object you're using
  #    - columns: hash of column names and values to insert into the delayed
  #               jobs table in addition to the handler
  #-----------------------------------------------------------------------------
  def self.use_handler(handler, columns = {})
    job = self.new
    job.handler = handler

    job
  end

  # factory method to create a new UniqueDelayedJob by specifying a method ton
  # call. will use delayed jobs' PerformableMethod class to enqueue the job
  #
  # arguments:
  #    - object: the object (or class or module) on which to call the method
  #    - method: the method to call (specify a symbol or string)
  #    - args_arr: an array of arguments to pass in the method call)
  #    - columns: hash of column names and values to insert into the delayed
  #               jobs table in addition to the handler
  #-----------------------------------------------------------------------------
  def self.call_method(object, method, args_arr, columns = {})
    job = self.new
    job.handler = Delayed::PerformableMethod.new(object, method, args_arr)

    job
  end


  # factory method to create a UniqueDelayedJob by specifying a block to
  # execute asynchronously
  # arguments:
  #    - columns: hash of column names and values to insert into the delayed
  #               jobs table in addition to the handler
  # NOTE: a block is expected
  #-----------------------------------------------------------------------------
  def self.run_block(columns = {}, &block)
    raise "missing a block in call to run_block" if !block_given?
    job = self.new
    job.handler = Delayed::EvaledJob.new(&block)

    job
  end


  # specify some additional columns to set in the delayed jobs table for this
  # row. be sure that you've migrated to add these columns to the delayed jobs
  # table. it is up to you to specify uniqueness constraints on any of the
  # columns you'd like to use to prevent duplicate entries in the delayed jobs
  # table. (it's also fine for some of these columns to not have unique
  # constraints, though this class will not prevent duplicate values for those
  # and they'll be for your use for other purposes.)
  #-----------------------------------------------------------------------------
  def add_delayed_jobs_columns(new_columns)
    columns.merge! new_columns
  end

  # put the job on the delayed jobs queue. if there already is a row in the
  # delayed jobs table with the same value in any of the unique columns
  # (enforced in the db), then the row will not be inserted
  #
  # arguments:
  #    priority: 
  #    run_at: 
  #-----------------------------------------------------------------------------
  def enqueue(priority = nil, run_at = nil)
    cols_to_insert = columns
    cols_to_insert.merge! :priority => priority if priority
    cols_to_insert.merge! :run_at => run_at if run_at
    cols_to_insert.merge! :handler => handler

    # try to catch if this raises an exception because of a duplicate key error
    # this should work for mysql and postgresql which both have the word
    # 'duplicate' followed (not necessarily immediately) by 'key'. ignoring
    # case cause case differs between the two cases
    # if doesn't look like a dupe key error, then reraise the exception
    begin
      Delayed::Job.create(cols_to_insert)
    rescue => e
      if /(duplicate).*(key)/i !~ e.message
        raise e
      end
    end

  end

  attr_accessor :columns

protected

  attr_accessor :handler


  # constructor used by the factory methods
  #-----------------------------------------------------------------------------
  def initialize(handler, columns = {})
    @handler = nil
    @call_method = { :method => nil, args => nil }
    @columns = {}
  end

end
