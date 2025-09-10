# frozen_string_literal: true

##
# Represents various levels of Guides (help sections)
# Guides are help sections written and organized by the team
# The levels are: 1. Item, 2. Section, 3. Subsection

module Guide
  def self.table_name_prefix
    'guide_'
  end
end
