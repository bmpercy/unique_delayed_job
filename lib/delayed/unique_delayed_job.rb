module Delayed

  # allows for specifying additional columns on the delayed_jobs table to help
  # prevent duplicate delayed jobs from being entered into the queue...but still
  # keep an easy interface to enqueuing delayed jobs
  #-----------------------------------------------------------------------------
  class UniqueDelayedJob

    cattr_reader :mark_all_locked_jobs_with_null

    @@mark_all_locked_jobs_with_null = true

    # enable the polciy that all delayed job rows that are marked with non-null
    # locked_by should have their columns set to null...ensuring that if a
    # job is currently executing then we CAN insert another delayed job with
    # the same unique keys.
    # This is useful if you want to run a job every time some event occurs, but
    # you're using this gem just to prevent having the same job twice in the
    # queue. But if a job is currently running, it may miss the change in state
    # due to the latest event, so a new job does need to be added to the queue.
    # setting the columns to null on any jobs currently locked should 
    # ensure this behavior.
    # This is the default behavior.
    #-----------------------------------------------------------------------------
    def self.mark_all_locked_jobs_with_null
      @mark_all_locked_jobs_with_null = true
    end

    # override the default behavior, and DO NOT mark the columns on a delayed
    # job that is currently locked to null. this prevents inserting a duplicate
    # job with a job that is currently running (e.g. if you only want to run
    # the job once). Default is mark_all_locked_jobs_with_null (see that method)
    #-----------------------------------------------------------------------------
    def self.do_not_mark_locked_jobs_with_null
      @mark_all_locked_jobs_with_null = false
    end


    # factory method to create a new UniqueDelayedJob from a delayed job handler
    # object (see delayed job documentation for requirements)
    #
    # arguments:
    #    - handler: the delayed jobs handler object you're using
    #    - columns: hash of column names and values to insert into the delayed
    #               jobs table in addition to the handler
    #---------------------------------------------------------------------------
    def self.use_handler(handler, columns = {})
      job = self.new(handler, columns)
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
    #---------------------------------------------------------------------------
    def self.call_method(object, method, args_arr, columns = {})
      job = self.new(Delayed::PerformableMethod.new(object, method, args_arr),
                     columns)
    end


    # factory method to create a UniqueDelayedJob by specifying a block that
    # is executed and whose result is stored as a string to be evaled by
    # delayed_job
    # arguments:
    #    - columns: hash of column names and values to insert into the delayed
    #               jobs table in addition to the handler
    # NOTE: a block is expected
    #---------------------------------------------------------------------------
    def self.run_eval(columns = {}, &block)
      raise "missing a block in call to run_block" if !block_given?
      job = self.new(Delayed::EvaledJob.new(&block), columns)
    end


    # specify some additional columns to set in the delayed jobs table for this
    # row. be sure that you've migrated to add these columns to the delayed jobs
    # table. it is up to you to specify uniqueness constraints on any of the
    # columns you'd like to use to prevent duplicate entries in the delayed jobs
    # table. (it's also fine for some of these columns to not have unique
    # constraints, though this class will not prevent duplicate values for those
    # and they'll be for your use for other purposes.)
    #---------------------------------------------------------------------------
    def add_delayed_jobs_columns(new_columns)
      columns.merge! new_columns
    end


    # put the job on the delayed jobs queue. if there already is a row in the
    # delayed jobs table with the same value in any of the unique columns
    # (enforced in the db), then the row will not be inserted
    #
    # return value:
    #   - if a new delayed job is inserted, the job object is returned
    #   - otherwise, returns nil
    #
    # arguments:
    #    priority: 
    #    run_at: 
    #---------------------------------------------------------------------------
    def enqueue(priority = nil, run_at = nil)
      if mark_all_locked_jobs_with_null && !columns.blank?
        null_setting_strings = []

        columns.each_key do |c|
          null_setting_strings << "#{c.to_s} = NULL"
        end

        Delayed::Job.update_all(null_setting_strings.join("\n              ,"),
                                "locked_by IS NOT NULL")
      end

      cols_to_insert = columns
      cols_to_insert.merge! :priority => priority if priority
      cols_to_insert.merge! :run_at => run_at if run_at
      cols_to_insert.merge! :handler => handler

      job = nil

      # try to catch if this raises an exception because of a duplicate key
      # error this should work for mysql and postgresql which both have the
      # word 'duplicate' followed (not necessarily immediately) by 'key'.
      # ignoring case cause case differs between the two cases
      # if doesn't look like a dupe key error, then reraise the exception
      begin
        job = Delayed::Job.create(cols_to_insert)
      rescue => e
        if /(duplicate).*(key)/i !~ e.message
          raise e
        end
      end

      return job
    end

    attr_accessor :columns

  protected

    attr_accessor :handler

    # constructor used by the factory methods
    #---------------------------------------------------------------------------
    def initialize(handler, columns = {})
      @handler = handler
      @columns = columns
    end

  end

end
