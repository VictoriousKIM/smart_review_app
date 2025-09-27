-- Create reviews table
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    campaign_id UUID REFERENCES public.campaigns(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    images TEXT[] DEFAULT '{}' NOT NULL,
    pros TEXT[] DEFAULT '{}' NOT NULL,
    cons TEXT[] DEFAULT '{}' NOT NULL,
    tags TEXT[] DEFAULT '{}' NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE NOT NULL,
    like_count INTEGER DEFAULT 0 NOT NULL,
    comment_count INTEGER DEFAULT 0 NOT NULL,
    status TEXT DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
    reward_earned INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- Ensure one review per user per campaign
    UNIQUE(campaign_id, user_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_reviews_campaign_id ON public.reviews(campaign_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON public.reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON public.reviews(rating);
CREATE INDEX IF NOT EXISTS idx_reviews_status ON public.reviews(status);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON public.reviews(created_at);
CREATE INDEX IF NOT EXISTS idx_reviews_is_verified ON public.reviews(is_verified);

-- Enable Row Level Security (RLS)
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Create policies for reviews
-- Anyone can view approved reviews
CREATE POLICY "Anyone can view approved reviews" ON public.reviews
    FOR SELECT USING (status = 'approved');

-- Users can view their own reviews
CREATE POLICY "Users can view own reviews" ON public.reviews
    FOR SELECT USING (auth.uid() = user_id);

-- Users can create reviews for campaigns they participated in
CREATE POLICY "Users can create reviews" ON public.reviews
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own reviews
CREATE POLICY "Users can update own reviews" ON public.reviews
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own reviews
CREATE POLICY "Users can delete own reviews" ON public.reviews
    FOR DELETE USING (auth.uid() = user_id);

-- Create trigger to automatically update updated_at
CREATE OR REPLACE TRIGGER update_reviews_updated_at
    BEFORE UPDATE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create function to update campaign participant count
CREATE OR REPLACE FUNCTION public.update_campaign_participant_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.campaigns 
        SET participant_count = participant_count + 1
        WHERE id = NEW.campaign_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.campaigns 
        SET participant_count = participant_count - 1
        WHERE id = OLD.campaign_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update participant count
CREATE OR REPLACE TRIGGER update_campaign_participant_count_trigger
    AFTER INSERT OR DELETE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.update_campaign_participant_count();
