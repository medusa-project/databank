class AddIdentifierSchemeToCreators < ActiveRecord::Migration
  def change
    add_column :creators, :identifier_scheme, :string
  end
end
