describe Travis::Scheduler::Schedule do
  describe 'setup' do
    before do
      # XXX: I tend to want to test this without knowing the
      # implementation details, but also don't want to refactor at
      # this stage (ever?).  Hmm...
      Travis::Database.stubs(:connect)
      Travis::Metrics.stubs(:setup)
      Travis::Exceptions::Reporter.stubs(:start)
      Travis::Notification.stubs(:setup)
      Travis::Addons.stubs(:register)
      Travis.config.logs_database = true
      Log.stubs(:establish_connection)
      Log::Part.stubs(:establish_connection)
      subject.stubs(:declare_exchanges_and_queues)
    end

    it 'does not explode' do
      subject.setup
    end
  end

  describe 'run' do
    it 'enqueues jobs' do
      subject.expects(:enqueue_jobs)
      subject.run
    end
  end
end
