require 'travis/rollout'

module Travis
  module Scheduler
    module Service
      class Event < Struct.new(:context, :event, :data)
        include Registry, Helper::Context, Helper::Locking, Helper::Logging,
          Helper::Metrics, Helper::Runner, Helper::With

        register :service, :event

        MSGS = {
          receive: 'Received event %s %s=%s for %s (state update count: %p)',
          ignore:  'Ignoring owner based on rollout: %s (type=%s id=%s)',
          test:    'Testing exception handling in Scheduler 2.0',
          drop:    'Owner group %s is locked and already being evaluated. Dropping event %s for %s=%s.'
        }

        def run
          info MSGS[:receive] % [event, type, obj.id, repo.slug, meta[:state_update_count]]
          Travis::Honeycomb.context.add('repo_slug', repo.slug)
          Travis::Honeycomb.context.add('state_update_count', meta[:state_update_count])
          meter
          inline :enqueue_owners, attrs
        rescue Lock::Redis::LockError => e
          info MSGS[:drop] % [e.key, event, type, data[:id]]
          Travis::Honeycomb.context.add('dropped', true)
        end

        private

          def rollout?(owner)
            Rollout.matches?({ uid: owner.id.to_i, owner: owner.login }, redis: Scheduler.redis)
          end

          def meter
            super(event.sub(':', '.'))
          end

          def attrs
            { owner_type: obj.owner_type, owner_id: obj.owner_id, jid: jid, meta: meta }
          end

          def obj
            @obj ||= Kernel.const_get(type.capitalize).find(data[:id])
          end

          def repo
            obj.repository
          end

          def state
            @state ||= State.new(owners, config)
          end

          def owners
            Owners.new(data, config)
          end

          def type
            event.split(':').first
          end

          def action
            event.split(':').last
          end

          def jid
            data[:jid]
          end

          def meta
            data[:meta] || {}
          end

          def src
            data[:src]
          end
      end
    end
  end
end
