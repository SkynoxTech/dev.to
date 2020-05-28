class ChatChannelMembershipPolicy < ApplicationPolicy
  def update?
    record.present? && user.id == record.user_id
  end

  def find_by_chat_channel_id?
    record.present? && user.id == record.user_id
  end

  def destroy?
    record.present? && user.id == record.user_id
  end

  def edit_membership?
    record.present? && user.id == record.user_id
  end

  def update_membership?
    record.present? && user.id == record.user_id
  end

  def destroy_membership?
    record.present? && user.id == record.user_id
  end
end
