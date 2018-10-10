describe Travis::Queue::LinuxSudoRequired do
  let(:config) { {} }
  let(:owner) { FactoryGirl.build(:user, login: 'cabbagen') }
  let(:repo) { FactoryGirl.build(:repo, owner: owner) }

  subject { described_class.new(repo, owner) }

  before do
    Travis::Scheduler.logger.stubs(:info)
  end

  context 'when enabled for all' do
    let(:enabled_for_all?) { true }

    it 'applies' do
      Travis::Features
      .stubs(:enabled_for_all?)
      .with(:linux_sudo_required)
      .returns(enabled_for_all?)
      expect(subject.apply?).to be true
    end
  end

  context 'when repo is active' do
    let(:active?) { true }

    it 'applies' do
      Travis::Features
      .stubs(:active?)
      .with(:linux_sudo_required, repo)
      .returns(active?)
      expect(subject.apply?).to be true
    end
  end

  context 'when owner is active' do
    let(:owner_active?) { true }

    it 'applies' do
      Travis::Features
      .stubs(:owner_active?)
      .with(:linux_sudo_required, owner)
      .returns(owner_active?)
      expect(subject.apply?).to be true
    end
  end

  context 'when first_job' do

    it 'applies' do
      subject.stubs(:first_job?).returns(true)
      expect(subject.apply?).to be true
    end
  end

  context 'when random' do

    it 'applies' do
      subject.stubs(:first_job?).returns(false)
      subject.stubs(:rollout_linux_sudo_required_percentage).returns(1)
      expect(subject.apply?).to be true
    end
  end
end
