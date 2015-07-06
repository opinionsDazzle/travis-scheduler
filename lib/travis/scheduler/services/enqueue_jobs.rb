require 'travis/support/instrumentation'
require 'travis/support/exceptions/handling'

require 'travis/scheduler/models/organization'
require 'travis/scheduler/models/user'
require 'travis/scheduler/payloads/worker'
require 'travis/scheduler/services/limit/default'
require 'travis/scheduler/services/limit/configurable'

module Travis
  module Scheduler
    module Services
      # Finds owners that have queueable jobs and for each owner:
      #
      #   * checks how many jobs can be enqueued
      #   * finds the oldest N queueable jobs and
      #   * enqueues them
      class EnqueueJobs
        TIMEOUT = 2

        extend Travis::Instrumentation, Travis::Exceptions::Handling

        def self.run
          new.run
        end

        def reports
          @reports ||= {}
        end

        def run
          enqueue_all && reports
        end
        # instrument :run
        rescues :run, from: Exception, backtrace: false

        private

          def strategy
            strategy = Travis.config.limit.strategy
            Travis.logger.info("Using the #{strategy} limit strategy.")
            Limit.const_get(strategy.camelize)
          end

          def enqueue_all
            grouped_jobs = jobs.group_by(&:owner)

            Metriks.timer('enqueue.total').time do
              grouped_jobs.each do |owner, jobs|
                next unless owner
                Metriks.timer('enqueue.full_enqueue_per_owner').time do
                  limit = nil
                  queueable = nil
                  Metriks.timer('enqueue.limit_per_owner').time do
                    limit = strategy.new(owner, jobs)
                    Travis.logger.info "About to evaluate jobs for: #{owner.login}."
                    queueable = limit.queueable
                  end

                  Metriks.timer('enqueue.enqueue_per_owner').time do
                    enqueue(queueable)
                  end

                  Metriks.timer('enqueue.report_per_owner').time do
                    reports[owner.login] = limit.report
                  end
                end
              end
            end
          end

          def enqueue(jobs)
            jobs.each do |job|
              Travis.logger.info("enqueueing slug=#{job.repository.slug} job_id=#{job.id}")
              Metriks.timer('enqueue.publish_job').time do
                publish(job)
              end

              Metriks.timer('enqueue.enqueue_job').time do
                job.update_attributes!(state: :queued, queued_at: Time.now.utc)
                # TODO needs to notify Pusher, right
                # notify(:queue)
              end
            end
          end

          def publish(job)
            Metriks.timer('enqueue.publish_job').time do
              payload = Payloads::Worker.new(job).data
              # check the properties are being set correctly,
              # and type is being used
              publisher(job.queue).publish(payload, properties: { type: "test", persistent: true })
            end
          end

          def jobs
            Metriks.timer('enqueue.fetch_jobs').time do
              jobs = Job.includes(:owner).queueable.all
              Travis.logger.info "Found #{jobs.size} jobs in total." if jobs.size > 0
              jobs
            end
          end

          def publisher(queue)
            Travis::Amqp::Publisher.builds(queue)
          end

          # class Instrument < Notification::Instrument
          #   def run_completed
          #     publish(msg: format(target.reports), reports: target.reports)
          #   end

          #   def format(reports)
          #     reports = Array(reports)
          #     if reports.any?
          #       reports = reports.map do |repo, report|
          #         "  #{repo}: #{report.map { |key, value| "#{key}: #{value}" }.join(', ')}"
          #       end
          #       "enqueued:\n#{reports.join("\n")}"
          #     else
          #       'nothing to enqueue.'
          #     end
          #   end
          # end
          # Instrument.attach_to(self)
      end
    end
  end
end
