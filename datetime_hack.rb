require 'active_record'

module CoHack
  module DatetimeHack
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def datetime_hack(*attributes)
        
        send :define_method, "combine_to_datetime".to_sym do |date_string, time_string|
          return nil if date_string.nil? or time_string.nil?  
          
          time_string.insert(2, ":") if time_string.length == 4
          
          hour, minutes  = time_string.match(/([0-9][0-9]\:[0-9][0-9])/)[0].split(":")
          
          ds = date_string.to_date
          Time.local ds.year, ds.month, ds.day, hour.to_i, minutes.to_i, 0, 0, (Time.zone.utc_offset / 3600)
        end
        
        send :define_method, "is_valid_time?".to_sym do |field|
          time = instance_variable_get("@#{field}")
          
          time.insert(2, ":") if time and time.length == 4
          
          if time.nil?
            # do nothing! it's cool!
          elsif time.match(/([0-9][0-9]\:[0-9][0-9])/)
            hour, minutes = time.split(":")
            
            errors.add(field, 'must be in valid 24 hour time') unless (hour.to_i >= 0 and hour.to_i <= 24)
            
            errors.add(field, 'has an invalid number of minutes') unless (minutes.to_i >= 0 and minutes.to_i <= 60)
          else
            errors.add(field, 'has an invalid time format, It must be in XX:YY')
          end
        end
        
        attributes.each do |attribute|
          attribute_base = attribute.to_s.split("_")[0]
          
          send :define_method, "#{attribute_base}_date=".to_sym do |date_value|
            instance_variable_set("@#{attribute_base}_date", date_value)
          end
          
          send :define_method, "#{attribute_base}_date".to_sym do
            date_value = instance_variable_get("@#{attribute_base}_date")
            if !date_value
              instance_variable_set("@#{attribute_base}_date", (self.send(attribute.to_sym).to_date.to_s rescue nil))
              date_value = instance_variable_get("@#{attribute_base}_date")
            end
            date_value
          end
          
          send :define_method, "#{attribute_base}_time=".to_sym do |time_value|
            instance_variable_set("@#{attribute_base}_time", time_value ) 
          end
          
          send :define_method, "#{attribute_base}_time".to_sym do
            time_value = instance_variable_get("@#{attribute_base}_time")
            if !time_value
              instance_variable_set("@#{attribute_base}_time", (self.send(attribute.to_sym).strftime("%H:%M") rescue nil ))
              time_value = instance_variable_get("@#{attribute_base}_time")
            end
            time_value
          end
          
          send :define_method, "#{attribute_base}_time_is_valid_time?" do
            self.send("is_valid_time?".to_sym, "#{attribute_base}_time".to_sym)
          end
                    
          send :define_method, "combine_#{attribute}".to_sym do
            
            date_value = instance_variable_get("@#{attribute_base}_date")
            time_value = instance_variable_get("@#{attribute_base}_time")
            
            return if !(date_value or time_value)
            
            self.send("#{attribute}=".to_sym, combine_to_datetime(date_value, time_value))
          end
          
          self.class_eval do
            validate "#{attribute_base}_time_is_valid_time?"
            before_save "combine_#{attribute}"
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, CoHack::DatetimeHack
