class CreateMailRecords < ActiveRecord::Migration
  def self.up
    create_table :mail_records do |t|
      t.column :email_address, :string
      t.column :email_client_app, :string
      t.column :created_on, :timestamp
    end
  end

  def self.down
    drop_table :mail_records
  end
end
