# frozen_string_literal: true

class VersionGroup

  attr_accessor :dataset, :group_hash

  def initialize(dataset)
    self.dataset = dataset
    self_version_entry = dataset.related_version_entry_hash
    self_version_entry[:selected] = true
    self.group_hash = Hash.new
    group_hash[:status] = "ok"
    group_hash[:entries] = [self_version_entry]

    # follow daisy chain of previous versions
    current_dataset = self
    current_group_count = 0
    max_group_count = 50

    while current_dataset && current_group_count < max_group_count
      previous_dataset = current_dataset.previous_idb_dataset
      break if previous_dataset.nil? || previous_dataset == current_dataset

      current_group_count += 1
      group_hash[:entries] << previous_dataset.related_version_entry_hash if previous_dataset
      current_dataset = previous_dataset
    end

    # reset pointer for chain of next versions
    current_dataset = self
    current_group_count = 0
    while current_dataset
      next_dataset = current_dataset.next_idb_dataset
      break if next_dataset.nil? || next_dataset == current_dataset

      unless next_dataset.is_unconfirmed_version?
        current_group_count += 1
        group_hash[:entries] << next_dataset.related_version_entry_hash
      end
      # go to next, if it exists, else set control to nil and break
      current_dataset = next_dataset
    end
    (group_hash[:entries].sort_by! {|k| k[:version] }).reverse!
  end

end
