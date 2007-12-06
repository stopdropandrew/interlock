
class ActionController::Base

  #
  # Build the fragment key from a particular context. This must be deterministic 
  # and stateful except for the tag. We can't scope the key to arbitrary params 
  # because the view doesn't have access to which are relevant and which are 
  # not.
  #
  # Note that the tag can be pretty much any object. Define #to_interlock_tag
  # if you need custom tagging for some class. ActiveRecord::Base already
  # has it defined appropriately.
  #
  # If you pass an Array of symbols as the tag, it will get value-mapped onto
  # params and sorted. This makes granular scoping easier, although it doesn't
  # sidestep the normal blanket invalidations.
  #
  def caching_key(ignore = nil, tag = nil)
    ignore = Array(ignore)
    ignore = Interlock::SCOPE_KEYS if ignore.include? :all    
    
    if (Interlock::SCOPE_KEYS - ignore).empty? and !tag
      raise UsageError, "You must specify a :tag if you are ignoring the entire default scope."
    end
      
    if tag.is_a? Array and tag.all? {|x| x.is_a? Symbol}
      tag = tag.sort_by do |key|
        key.to_s
      end.map do |key| 
        params[key].to_interlock_tag
      end.join(";")
    end
    
    Interlock.caching_key(      
      ignore.include?(:controller) ? 'any' : controller_name,
      ignore.include?(:action) ? 'any' : action_name,
      ignore.include?(:id) ? 'all' : params[:id],
      tag
    )
  end
  
  # Mark a controller block for caching. Accepts a list of class dependencies for
  # invalidation, as well as a :tag key for explicit fragment scoping.
  def behavior_cache(*args)  
    conventional_class = begin; controller_name.classify.constantize; rescue NameError; end
    options, dependencies = Interlock.extract_options_and_dependencies(args, conventional_class)
    
    raise UsageError, ":ttl has no effect in a behavior_cache block" if options[:ttl]
    
    key = caching_key(options.value_for_indifferent_key(:ignore), options.value_for_indifferent_key(:tag))      
    Interlock.register_dependencies(dependencies, key)
        
    # See if the fragment exists, and run the block if it doesn't.
    unless ActionController::Base.fragment_cache_store.get(key)    
      Interlock.say key, "is running the controller block"
      yield
    end
  end
  
  alias :caching :behavior_cache # XXX Deprecated

end