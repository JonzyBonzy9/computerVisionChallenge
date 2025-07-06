function Views = getViews(app)
    Views = struct();
    Views.TimeSlider = TimeSliderView(app);
    Views.GridView = GridView(app);
    Views.Overlay = OverlayView(app);
end