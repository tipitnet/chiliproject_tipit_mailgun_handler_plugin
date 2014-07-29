module TipitMailHandler

  module AttachmentPatch

    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        alias_method_chain :before_save, :tipit_patch
        before_save :before_save
      end

    end

    module ClassMethods
    end

    module InstanceMethods

      def file_from_mail=(incoming_file)
        unless incoming_file.nil?
          @is_from_email = true
          @temp_file = incoming_file
          self.filename = sanitize_filename(@temp_file.filename)
          self.disk_filename = Attachment.disk_filename(filename)
          self.content_type = @temp_file.content_type.to_s.chomp
          if content_type.blank?
            self.content_type = Redmine::MimeType.of(filename)
          end
          self.filesize = @temp_file.size
        end
      end

      # Copies the temporary file to its final location
      # and computes its MD5 hash
      def before_save_with_tipit_patch
        if @temp_file && (@temp_file.size > 0)
          logger.debug("saving '#{self.diskfile}'")
          md5 = Digest::MD5.new
          if (@is_from_email)
            File.open(diskfile, "wb") do |f|
              content = @temp_file.read
              f.write(content)
              md5.update(content)
            end
            self.digest = md5.hexdigest
          else
            File.open(diskfile, "wb") do |f|
              buffer = ""
              while (buffer = @temp_file.read(8192))
                f.write(buffer)
                md5.update(buffer)
              end
            end
            self.digest = md5.hexdigest
          end

        end
        # Don't save the content type if it's longer than the authorized length
        if self.content_type && self.content_type.length > 255
          self.content_type = nil
        end
      end
    end
  end
end
