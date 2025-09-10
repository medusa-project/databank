class AddHeadingAndBodyToGuideSections < ActiveRecord::Migration[6.1]
  def change
    add_column :guide_sections, :heading, :string
    add_column :guide_sections, :body, :string
  end
end
