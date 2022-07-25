class CreateFeaturedResearchers < ActiveRecord::Migration
  def change
    create_table :featured_researchers do |t|
      t.string :name
      t.string :title
      t.text :bio
      t.text :testimonial
      t.string :binary

      t.timestamps null: false
    end
  end
end
