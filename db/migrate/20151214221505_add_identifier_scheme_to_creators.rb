class AddIdentifierSchemeToCreators < ActiveRecord::Migration[4.2]
  def change
    add_column :creators, :identifier_scheme, :string
  end
end
