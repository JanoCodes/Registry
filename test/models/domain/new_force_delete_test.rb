require 'test_helper'

class NewDomainForceDeleteTest < ActiveSupport::TestCase
  setup do
    @domain = domains(:shop)
    @original_redemption_grace_period = Setting.redemption_grace_period
  end

  teardown do
    Setting.redemption_grace_period = @original_redemption_grace_period
  end

  def test_schedules_force_delete_fast_track
    assert_not @domain.force_delete_scheduled?
    Setting.redemption_grace_period = 45
    travel_to Time.zone.parse('2010-07-05')

    @domain.schedule_force_delete(type: :fast_track)
    @domain.reload

    assert @domain.force_delete_scheduled?
    assert_equal Date.parse('2010-08-19'), @domain.force_delete_date
    assert_equal Date.parse('2010-07-05'), @domain.force_delete_start
  end

  def test_schedules_force_delete_soft_year_ahead
    @domain.update(valid_to: Time.zone.parse('2012-08-05'))
    assert_not @domain.force_delete_scheduled?
    Setting.redemption_grace_period = 45
    travel_to Time.zone.parse('2010-07-05')

    @domain.schedule_force_delete(type: :soft)
    @domain.reload

    assert @domain.force_delete_scheduled?
    assert_equal Date.parse('2011-08-19'), @domain.force_delete_date
    assert_equal Date.parse('2011-07-05'), @domain.force_delete_start
  end

  def test_schedules_force_delete_soft_less_than_year_ahead
    @domain.update(valid_to: Time.zone.parse('2011-08-05'))
    assert_not @domain.force_delete_scheduled?
    Setting.redemption_grace_period = 45
    travel_to Time.zone.parse('2010-07-05')

    @domain.schedule_force_delete(type: :soft)
    @domain.reload

    assert @domain.force_delete_scheduled?
    assert_equal Date.parse('2010-08-19'), @domain.force_delete_date
    assert_equal Date.parse('2010-07-05'), @domain.force_delete_start
  end

  def test_scheduling_soft_force_delete_adds_corresponding_statuses
    statuses_to_be_added = [
      DomainStatus::FORCE_DELETE,
      DomainStatus::SERVER_RENEW_PROHIBITED,
      DomainStatus::SERVER_TRANSFER_PROHIBITED,
    ]

    @domain.schedule_force_delete(type: :soft)
    @domain.reload
    assert (@domain.statuses & statuses_to_be_added) == statuses_to_be_added
  end

  def test_scheduling_fast_track_force_delete_adds_corresponding_statuses
    statuses_to_be_added = [
      DomainStatus::FORCE_DELETE,
      DomainStatus::SERVER_RENEW_PROHIBITED,
      DomainStatus::SERVER_TRANSFER_PROHIBITED,
    ]

    @domain.schedule_force_delete(type: :fast_track)
    @domain.reload
    assert (@domain.statuses & statuses_to_be_added) == statuses_to_be_added
  end

  def test_scheduling_force_delete_allows_domain_deletion
    statuses_to_be_removed = [
      DomainStatus::CLIENT_DELETE_PROHIBITED,
      DomainStatus::SERVER_DELETE_PROHIBITED,
    ]

    @domain.statuses = statuses_to_be_removed + %w[other-status]
    @domain.schedule_force_delete(type: :fast_track)
    @domain.reload
    assert_empty @domain.statuses & statuses_to_be_removed
  end

  def test_scheduling_force_delete_stops_pending_actions
    statuses_to_be_removed = [
      DomainStatus::PENDING_UPDATE,
      DomainStatus::PENDING_TRANSFER,
      DomainStatus::PENDING_RENEW,
      DomainStatus::PENDING_CREATE,
    ]

    @domain.statuses = statuses_to_be_removed + %w[other-status]
    @domain.schedule_force_delete(type: :fast_track)
    @domain.reload
    assert_empty @domain.statuses & statuses_to_be_removed, 'Pending actions should be stopped'
  end

  def test_scheduling_force_delete_preserves_current_statuses
    @domain.statuses = %w[test1 test2]
    @domain.schedule_force_delete(type: :fast_track)
    @domain.reload
    assert_equal %w[test1 test2], @domain.statuses_before_force_delete
  end

  def test_scheduling_force_delete_bypasses_validation
    @domain = domains(:invalid)
    @domain.schedule_force_delete(type: :fast_track)
    assert @domain.force_delete_scheduled?
  end

  def test_force_delete_cannot_be_scheduled_when_a_domain_is_discarded
    @domain.update!(statuses: [DomainStatus::DELETE_CANDIDATE])
    assert_raises StandardError do
      @domain.schedule_force_delete(type: :fast_track)
    end
  end

  def test_force_delete_sets_client_hold_on_condition
    statuses_to_be_added = [DomainStatus::CLIENT_HOLD]
    @domain.update_columns(statuses: [DomainStatus::FORCE_DELETE],
                           force_delete_date: Time.zone.parse('2010-08-05'),
                           force_delete_start: Time.zone.parse('2010-08-05') - 45.days)
    travel_to Time.zone.parse('2010-07-05')
    assert @domain.force_delete_scheduled?

    @domain.set_hold
    assert (@domain.statuses & statuses_to_be_added) == statuses_to_be_added
  end

  def test_cancels_force_delete
    @domain.update_columns(statuses: [DomainStatus::FORCE_DELETE],
                           force_delete_date: Time.zone.parse('2010-07-05'),
                           force_delete_start: Time.zone.parse('2010-07-05') - 45.days)
    assert @domain.force_delete_scheduled?

    @domain.cancel_force_delete
    @domain.reload

    assert_not @domain.force_delete_scheduled?
    assert_nil @domain.force_delete_date
    assert_nil @domain.force_delete_start
  end

  def test_cancelling_force_delete_bypasses_validation
    @domain = domains(:invalid)
    @domain.schedule_force_delete(type: :fast_track)
    @domain.cancel_force_delete
    assert_not @domain.force_delete_scheduled?
  end

  def test_cancelling_force_delete_removes_statuses_that_were_set_on_force_delete
    statuses = [
      DomainStatus::FORCE_DELETE,
      DomainStatus::SERVER_RENEW_PROHIBITED,
      DomainStatus::SERVER_TRANSFER_PROHIBITED,
    ]
    @domain.statuses = @domain.statuses + statuses
    @domain.schedule_force_delete(type: :fast_track)

    @domain.cancel_force_delete
    @domain.reload

    assert_empty @domain.statuses & statuses
  end

  def test_cancelling_force_delete_restores_statuses_that_a_domain_had_before_force_delete
    @domain.statuses_before_force_delete = ['test1', DomainStatus::DELETE_CANDIDATE]

    @domain.cancel_force_delete
    @domain.reload

    assert_equal ['test1', DomainStatus::DELETE_CANDIDATE], @domain.statuses
    assert_nil @domain.statuses_before_force_delete
  end
end
