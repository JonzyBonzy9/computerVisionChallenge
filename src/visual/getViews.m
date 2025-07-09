function Views = getViews(app)
    Views = struct();
    Views.Overlay = OverlayView(app);
    Views.Difference = DifferenceView(app);
    Views.TimeSlider = TimeSliderView(app);
    Views.GridView = GridView(app);    
end